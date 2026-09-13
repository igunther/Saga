import Foundation
import OSLog

/// Checks the public App Store listing and reports results. The host app owns all presentation.
public actor SagaUpdateService {
    public let configuration: SagaUpdateConfiguration

    private let repositoryFactory: @Sendable (String) -> SagaUpdateRepository
    private let regionRepository: StorefrontRegionRepository
    private var repositories: [String: SagaUpdateRepository] = [:]
    private var selectedCountry: String?
    private var regionGeneration = 0
    private var current = SagaUpdateSnapshot(release: nil, availability: .unknown, checkedAt: nil)
    private var snapshotSubscribers: [UUID: AsyncStream<SagaUpdateSnapshot>.Continuation] = [:]
    private var releaseSubscribers: [UUID: AsyncStream<SagaStoreRelease>.Continuation] = [:]
    private var monitoringTask: Task<Void, Never>?
    private var storefrontTask: Task<Void, Never>?
    private var isActive = false

    init(configuration: SagaUpdateConfiguration, regionRepository: StorefrontRegionRepository,
         repositoryFactory: @escaping @Sendable (String) -> SagaUpdateRepository) {
        self.configuration = configuration
        self.regionRepository = regionRepository
        self.repositoryFactory = repositoryFactory
    }

    /// The latest known value, including a persisted result from a previous launch.
    public func snapshot() async -> SagaUpdateSnapshot {
        await selectCurrentRegion()
        return current
    }

    /// Replays the current value immediately and publishes subsequent changes.
    public func snapshots() async -> AsyncStream<SagaUpdateSnapshot> {
        let initial = await snapshot()
        let id = UUID()
        return AsyncStream { continuation in
            snapshotSubscribers[id] = continuation
            continuation.yield(initial)
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeSnapshotSubscriber(id) }
            }
        }
    }

    /// Emits once per newly discovered App Store version and country, across app launches.
    /// Subscribe before starting monitoring; use `snapshot()` to recover current state.
    public func newVersions() -> AsyncStream<SagaStoreRelease> {
        let id = UUID()
        return AsyncStream { continuation in
            releaseSubscribers[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeReleaseSubscriber(id) }
            }
        }
    }

    /// Starts due checks and keeps their cadence while the host app is active.
    public func setActive(_ active: Bool) {
        guard isActive != active else { return }
        isActive = active
        monitoringTask?.cancel()
        monitoringTask = nil
        storefrontTask?.cancel()
        storefrontTask = nil
        guard active else { return }
        startMonitor()
        if case .automatic = configuration.region {
            storefrontTask = Task { [weak self, regionRepository] in
                for await code in regionRepository.countryCodeUpdates() {
                    guard !Task.isCancelled else { return }
                    await self?.selectRegion(for: code)
                }
            }
        }
    }

    private func startMonitor() {
        monitoringTask = Task { [weak self] in await self?.monitor() }
    }

    private func repository(for country: String) -> SagaUpdateRepository {
        if let repository = repositories[country] { return repository }
        let repository = repositoryFactory(country)
        repositories[country] = repository
        return repository
    }

    private func selectCurrentRegion() async {
        switch configuration.region {
        case .countryCode(let country): await selectCountry(country)
        case .automatic:
            await selectRegion(for: await regionRepository.currentCountryCode())
        }
    }

    private func selectRegion(for countryCode: String?) async {
        guard case .automatic(let fallback) = configuration.region else { return }
        await selectCountry(countryCode ?? fallback)
    }

    private func selectCountry(_ country: String) async {
        guard selectedCountry != country else { return }
        selectedCountry = country
        regionGeneration += 1
        let generation = regionGeneration
        let cached = await repository(for: country).cachedRelease()
        guard selectedCountry == country, regionGeneration == generation else { return }
        current = cached.map { makeSnapshot(release: $0.0, checkedAt: $0.1) }
            ?? SagaUpdateSnapshot(release: nil, availability: .unknown, checkedAt: nil)
        publish(current)
        if isActive {
            monitoringTask?.cancel()
            startMonitor()
        }
    }

    /// A manual refresh may bypass the configured interval, for example from Settings.
    @discardableResult
    public func refresh(force: Bool = false) async throws -> SagaUpdateSnapshot {
        _ = await snapshot()
        guard let country = selectedCountry else { throw CancellationError() }
        let generation = regionGeneration
        let repository = repository(for: country)
        guard let installed = SagaVersion(configuration.installedVersion) else {
            current = SagaUpdateSnapshot(
                release: current.release,
                availability: .unknown,
                checkedAt: current.checkedAt,
                lastError: .invalidInstalledVersion
            )
            publish(current)
            throw SagaUpdateError.invalidInstalledVersion
        }
        do {
            let result = try await repository.check(
                appStoreID: configuration.appStoreID,
                countryCode: country,
                checkInterval: configuration.checkInterval,
                retryInterval: configuration.retryInterval,
                now: Date(),
                force: force
            )
            try Task.checkCancellation()
            await selectCurrentRegion()
            guard selectedCountry == country, regionGeneration == generation else { throw CancellationError() }
            guard let storeVersion = SagaVersion(result.release.version) else {
                throw SagaUpdateError.invalidStoreResponse
            }
            let release = SagaStoreReleaseMapper.map(result.release)
            let available = installed < storeVersion
            current = SagaUpdateSnapshot(
                release: release,
                availability: available ? .updateAvailable : .upToDate,
                checkedAt: result.checkedAt,
                lastError: result.fetched ? nil : current.lastError
            )
            publish(current)
            if available, await repository.reportIfNew(version: release.version) {
                await selectCurrentRegion()
                guard selectedCountry == country, regionGeneration == generation else { throw CancellationError() }
                for continuation in releaseSubscribers.values { continuation.yield(release) }
            }
            return current
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            await selectCurrentRegion()
            guard selectedCountry == country, regionGeneration == generation else { throw CancellationError() }
            let mapped: SagaUpdateError
            switch error {
            case let domainError as SagaUpdateError: mapped = domainError
            case SagaUpdateRepositoryError.appUnavailable: mapped = .appUnavailable
            case SagaUpdateRepositoryError.invalidResponse: mapped = .invalidStoreResponse
            default: mapped = .networkUnavailable
            }
            current = SagaUpdateSnapshot(
                release: current.release,
                availability: current.availability,
                checkedAt: current.checkedAt,
                lastError: mapped
            )
            publish(current)
            throw mapped
        }
    }

    private func monitor() async {
        _ = await snapshot()
        while !Task.isCancelled {
            guard let country = selectedCountry else { return }
            let due = await repository(for: country).nextCheckDate(
                checkInterval: configuration.checkInterval,
                retryInterval: configuration.retryInterval
            )
            let delay = max(0, due.timeIntervalSinceNow)
            if delay > 0 {
                #if os(iOS)
                if configuration.backgroundTaskIdentifier != nil {
                    do {
                        try await scheduleBackgroundRefresh()
                    } catch {
                        Logger(subsystem: "SagaUpdates", category: "BackgroundRefresh")
                            .error("Scheduling update refresh failed: \(String(describing: error))")
                    }
                }
                #endif
                do { try await Task.sleep(for: .seconds(delay)) }
                catch { return }
            }
            guard !Task.isCancelled else { return }
            do { try await refresh() }
            catch is CancellationError { return }
            catch SagaUpdateError.invalidInstalledVersion { return }
            catch { /* Failure is published in the snapshot; retry follows retryInterval. */ }
        }
    }

    func nextCheckDate() async -> Date {
        await selectCurrentRegion()
        guard let selectedCountry else { return .distantPast }
        return await repository(for: selectedCountry).nextCheckDate(
            checkInterval: configuration.checkInterval,
            retryInterval: configuration.retryInterval
        )
    }

    private func makeSnapshot(release: StoreReleaseModel, checkedAt: Date) -> SagaUpdateSnapshot {
        guard let installed = SagaVersion(configuration.installedVersion) else {
            return SagaUpdateSnapshot(release: nil, availability: .unknown, checkedAt: checkedAt,
                                      lastError: .invalidInstalledVersion)
        }
        guard let store = SagaVersion(release.version) else {
            return SagaUpdateSnapshot(release: nil, availability: .unknown, checkedAt: checkedAt,
                                      lastError: .invalidStoreResponse)
        }
        return SagaUpdateSnapshot(
            release: SagaStoreReleaseMapper.map(release),
            availability: installed < store ? .updateAvailable : .upToDate,
            checkedAt: checkedAt
        )
    }

    private func publish(_ snapshot: SagaUpdateSnapshot) {
        for continuation in snapshotSubscribers.values { continuation.yield(snapshot) }
    }

    private func removeSnapshotSubscriber(_ id: UUID) { snapshotSubscribers[id] = nil }
    private func removeReleaseSubscriber(_ id: UUID) { releaseSubscribers[id] = nil }
}
