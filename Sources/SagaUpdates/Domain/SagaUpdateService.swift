import Foundation
import OSLog

/// Checks the public App Store listing and reports results. The host app owns all presentation.
public actor SagaUpdateService {
    public let configuration: SagaUpdateConfiguration

    private let repository: SagaUpdateRepository
    private var current = SagaUpdateSnapshot(release: nil, availability: .unknown, checkedAt: nil)
    private var snapshotSubscribers: [UUID: AsyncStream<SagaUpdateSnapshot>.Continuation] = [:]
    private var releaseSubscribers: [UUID: AsyncStream<SagaStoreRelease>.Continuation] = [:]
    private var monitoringTask: Task<Void, Never>?
    private var hasLoadedCache = false

    init(configuration: SagaUpdateConfiguration, repository: SagaUpdateRepository) {
        self.configuration = configuration
        self.repository = repository
    }

    /// The latest known value, including a persisted result from a previous launch.
    public func snapshot() async -> SagaUpdateSnapshot {
        if !hasLoadedCache, let (release, checkedAt) = await repository.cachedRelease() {
            current = makeSnapshot(release: release, checkedAt: checkedAt)
        }
        hasLoadedCache = true
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

    /// Emits once per newly discovered App Store version, across app launches.
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
        monitoringTask?.cancel()
        monitoringTask = nil
        guard active else { return }
        monitoringTask = Task { [weak self] in
            guard let self else { return }
            await self.monitor()
        }
    }

    /// A manual refresh may bypass the configured interval, for example from Settings.
    @discardableResult
    public func refresh(force: Bool = false) async throws -> SagaUpdateSnapshot {
        _ = await snapshot()
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
                countryCode: configuration.countryCode,
                checkInterval: configuration.checkInterval,
                retryInterval: configuration.retryInterval,
                now: Date(),
                force: force
            )
            try Task.checkCancellation()
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
                for continuation in releaseSubscribers.values { continuation.yield(release) }
            }
            return current
        } catch is CancellationError {
            throw CancellationError()
        } catch {
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
        let cached = await snapshot()
        publish(cached)
        while !Task.isCancelled {
            let due = await repository.nextCheckDate(
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
        await repository.nextCheckDate(
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
