import Foundation
import Testing
@testable import SagaUpdates

private actor StubLookup: AppStoreLooking {
    private(set) var calls = 0
    var result: Result<AppStoreReleaseDTO, AppStoreLookupError>
    let delay: Duration

    init(result: Result<AppStoreReleaseDTO, AppStoreLookupError>, delay: Duration = .zero) {
        self.result = result
        self.delay = delay
    }

    func lookup(appStoreID: Int, countryCode: String) async throws -> AppStoreReleaseDTO {
        calls += 1
        if delay > .zero { try await Task.sleep(for: delay) }
        return try result.get()
    }
}

private func temporarySuiteName() -> String {
    "SagaUpdatesTests.\(UUID())"
}

private func release(_ version: String) -> AppStoreReleaseDTO {
    AppStoreReleaseDTO(
        trackId: 123,
        version: version,
        trackViewUrl: URL(string: "https://apps.apple.com/app/id123")!
    )
}

@Test func numericVersionComparison() {
    #expect(SagaVersion("1.10")! > SagaVersion("1.9")!)
    #expect(SagaVersion("2.0")! == SagaVersion("2")!)
    #expect(SagaVersion("1.2.1")! > SagaVersion("1.2")!)
    #expect(SagaVersion("1..2") == nil)
    #expect(SagaVersion("1.2-beta") == nil)
}

@Test func releaseMappersPreserveStoreValues() {
    let dto = release("0.0.1")
    let model = StoreReleaseModelMapper.map(dto)
    let domain = SagaStoreReleaseMapper.map(model)
    #expect(model.version == dto.version)
    #expect(model.storeURL == dto.trackViewUrl)
    #expect(domain.version == "0.0.1")
    #expect(domain.storeURL == dto.trackViewUrl)
}

@Test func repositoryCachesAndDeduplicatesReporting() async throws {
    let lookup = StubLookup(result: .success(release("1.10")))
    let repository = SagaUpdateRepository(
        appStoreID: 123,
        countryCode: "NO",
        lookup: lookup,
        store: UserDefaultsUpdateCacheStore(suiteName: temporarySuiteName())
    )
    let now = Date(timeIntervalSince1970: 1_000_000)
    let first = try await repository.check(
        appStoreID: 123, countryCode: "NO", checkInterval: 86_400,
        retryInterval: 3_600, now: now
    )
    let second = try await repository.check(
        appStoreID: 123, countryCode: "NO", checkInterval: 86_400,
        retryInterval: 3_600, now: now.addingTimeInterval(60)
    )
    #expect(first.fetched)
    #expect(!second.fetched)
    #expect(await lookup.calls == 1)
    #expect(await repository.reportIfNew(version: "1.10"))
    #expect(!(await repository.reportIfNew(version: "1.10")))
}

@Test func simultaneousChecksShareOneLookup() async throws {
    let lookup = StubLookup(result: .success(release("2.0")), delay: .milliseconds(20))
    let repository = SagaUpdateRepository(
        appStoreID: 123, countryCode: "NO", lookup: lookup,
        store: UserDefaultsUpdateCacheStore(suiteName: temporarySuiteName())
    )
    let now = Date(timeIntervalSince1970: 1_000_000)
    async let first = repository.check(
        appStoreID: 123, countryCode: "NO", checkInterval: 86_400,
        retryInterval: 3_600, now: now
    )
    async let second = repository.check(
        appStoreID: 123, countryCode: "NO", checkInterval: 86_400,
        retryInterval: 3_600, now: now
    )
    let results = try await [first, second]
    #expect(results.allSatisfy { $0.release.version == "2.0" })
    #expect(await lookup.calls == 1)
}

@Test func failedLookupWaitsForRetryInterval() async throws {
    let lookup = StubLookup(result: .failure(.transport))
    let repository = SagaUpdateRepository(
        appStoreID: 123, countryCode: "NO", lookup: lookup,
        store: UserDefaultsUpdateCacheStore(suiteName: temporarySuiteName())
    )
    let now = Date(timeIntervalSince1970: 1_000_000)
    do {
        _ = try await repository.check(
            appStoreID: 123, countryCode: "NO", checkInterval: 86_400,
            retryInterval: 3_600, now: now
        )
        Issue.record("Expected a network error")
    } catch {
        #expect(error is SagaUpdateRepositoryError)
    }
    #expect(await repository.nextCheckDate(checkInterval: 86_400, retryInterval: 3_600)
            == now.addingTimeInterval(3_600))
    do {
        _ = try await repository.check(
            appStoreID: 123, countryCode: "NO", checkInterval: 86_400,
            retryInterval: 3_600, now: now.addingTimeInterval(60)
        )
        Issue.record("Expected the retry to be deferred")
    } catch {
        #expect(error as? SagaUpdateRepositoryError == .retryDeferred)
    }
    #expect(await lookup.calls == 1)
}

@Test func cachedReleaseSurvivesServiceRestart() async throws {
    let suiteName = temporarySuiteName()
    let configuration = SagaUpdateConfiguration(
        appStoreID: 123, installedVersion: "1.9", countryCode: "NO"
    )
    let first = SagaUpdateService(
        configuration: configuration,
        lookup: StubLookup(result: .success(release("1.10"))),
        storageSuiteName: suiteName
    )
    _ = try await first.refresh()
    let second = SagaUpdateService(
        configuration: configuration,
        lookup: StubLookup(result: .failure(.transport)),
        storageSuiteName: suiteName
    )
    let restored = await second.snapshot()
    #expect(restored.availability == .updateAvailable)
    #expect(restored.release?.version == "1.10")
    #expect(restored.checkedAt != nil)
}

@Test func serviceEmitsNewVersionEvent() async throws {
    let service = SagaUpdateService(
        configuration: SagaUpdateConfiguration(appStoreID: 123, installedVersion: "1.9", countryCode: "NO"),
        lookup: StubLookup(result: .success(release("1.10"))),
        storageSuiteName: temporarySuiteName()
    )
    let stream = await service.newVersions()
    var iterator = stream.makeAsyncIterator()
    _ = try await service.refresh()
    let event = await iterator.next()
    #expect(event?.version == "1.10")
}

@Test func invalidInstalledVersionIsReportedWithoutLookup() async {
    let lookup = StubLookup(result: .success(release("2.0")))
    let service = SagaUpdateService(
        configuration: SagaUpdateConfiguration(appStoreID: 123, installedVersion: "1.0-beta", countryCode: "NO"),
        lookup: lookup,
        storageSuiteName: temporarySuiteName()
    )
    do {
        _ = try await service.refresh()
        Issue.record("Expected invalid installed version")
    } catch {
        #expect(error as? SagaUpdateError == .invalidInstalledVersion)
    }
    #expect(await lookup.calls == 0)
    #expect(await service.snapshot().lastError == .invalidInstalledVersion)
}

@Test func serviceReportsAvailableVersionAndKeepsCachedStateAfterFailure() async throws {
    let lookup = StubLookup(result: .success(release("1.10")))
    let service = SagaUpdateService(
        configuration: SagaUpdateConfiguration(appStoreID: 123, installedVersion: "1.9", countryCode: "NO"),
        lookup: lookup,
        storageSuiteName: temporarySuiteName()
    )
    let first = try await service.refresh()
    #expect(first.availability == .updateAvailable)
    #expect(first.release?.version == "1.10")
    await lookup.setResult(.failure(.transport))
    do {
        try await service.refresh(force: true)
        Issue.record("Expected the forced check to fail")
    } catch {
        #expect(error as? SagaUpdateError == .networkUnavailable)
    }
    let stale = await service.snapshot()
    #expect(stale.availability == .updateAvailable)
    #expect(stale.release?.version == "1.10")
    #expect(stale.lastError == .networkUnavailable)
    let reused = try await service.refresh()
    #expect(reused.lastError == .networkUnavailable)
}

private extension StubLookup {
    func setResult(_ newResult: Result<AppStoreReleaseDTO, AppStoreLookupError>) {
        result = newResult
    }
}

/// Lock protects both current storefront and live observer registrations.
private final class FakeRegionSource: StorefrontRegionSourcing, @unchecked Sendable {
    private let lock = NSLock()
    private var code: String?
    private var observers: [UUID: AsyncStream<String?>.Continuation] = [:]
    private var registrations = 0
    private var registrationWaiters: [(Int, CheckedContinuation<Void, Never>)] = []

    init(_ code: String?) { self.code = code }

    func currentCountryCode() async -> String? { lock.withLock { code } }

    func countryCodeUpdates() -> AsyncStream<String?> {
        let id = UUID()
        return AsyncStream { continuation in
            let ready = lock.withLock { () -> [CheckedContinuation<Void, Never>] in
                observers[id] = continuation
                registrations += 1
                let ready = registrationWaiters.filter { $0.0 <= registrations }.map(\.1)
                registrationWaiters.removeAll { $0.0 <= registrations }
                return ready
            }
            for waiter in ready { waiter.resume() }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.withLock { self.observers[id] = nil }
            }
        }
    }

    func change(to newCode: String?) {
        let continuations = lock.withLock { () -> [AsyncStream<String?>.Continuation] in
            code = newCode
            return Array(observers.values)
        }
        for continuation in continuations { continuation.yield(newCode) }
    }

    var observerCount: Int { lock.withLock { observers.count } }
    var registrationCount: Int { lock.withLock { registrations } }

    func waitForRegistrations(_ count: Int) async {
        await withCheckedContinuation { continuation in
            let ready = lock.withLock { () -> Bool in
                if registrations >= count { return true }
                registrationWaiters.append((count, continuation))
                return false
            }
            if ready { continuation.resume() }
        }
    }
}

private actor GatedLookup: AppStoreLooking {
    private var pending: [String: CheckedContinuation<AppStoreReleaseDTO, Error>] = [:]
    private var waiters: [String: CheckedContinuation<Void, Never>] = [:]
    private(set) var countries: [String] = []

    func lookup(appStoreID: Int, countryCode: String) async throws -> AppStoreReleaseDTO {
        countries.append(countryCode)
        return try await withCheckedThrowingContinuation { continuation in
            pending[countryCode] = continuation
            waiters.removeValue(forKey: countryCode)?.resume()
        }
    }

    func waitForCall(_ country: String) async {
        if pending[country] != nil { return }
        await withCheckedContinuation { waiters[country] = $0 }
    }

    func complete(_ country: String, version: String) {
        pending.removeValue(forKey: country)?.resume(returning: release(version))
    }
}

private func automaticService(source: FakeRegionSource, lookup: any AppStoreLooking,
                              suite: String = temporarySuiteName()) -> SagaUpdateService {
    SagaUpdateService(
        configuration: SagaUpdateConfiguration(appStoreID: 123, installedVersion: "1.0",
                                               region: .automatic(fallbackCountryCode: "no")),
        lookup: lookup, regionSource: source,
        store: UserDefaultsUpdateCacheStore(suiteName: suite)
    )
}

@Test func explicitRegionIgnoresStorefront() async throws {
    let source = FakeRegionSource("USA")
    let lookup = GatedLookup()
    let configuration = SagaUpdateConfiguration(appStoreID: 123, installedVersion: "1.0", countryCode: "no")
    #expect(configuration.countryCode == "NO")
    #expect(configuration.region == .countryCode("NO"))
    let service = SagaUpdateService(configuration: configuration, lookup: lookup,
                                    regionSource: source,
                                    store: UserDefaultsUpdateCacheStore(suiteName: temporarySuiteName()))
    let refresh = Task { try await service.refresh() }
    await lookup.waitForCall("NO")
    source.change(to: "DEU")
    await lookup.complete("NO", version: "2.0")
    #expect(try await refresh.value.availability == .updateAvailable)
    #expect(source.registrationCount == 0)
}

@Test func alpha3ConversionAndFallbackAreIndependentOfDeviceLanguage() async throws {
    #expect(StorefrontCountryCode.alpha2(from: "NOR") == "NO")
    #expect(StorefrontCountryCode.alpha2(from: "usa") == "US")
    #expect(StorefrontCountryCode.alpha2(from: "DEU") == "DE")
    #expect(StorefrontCountryCode.alpha2(from: "GBR") == "GB")
    #expect(StorefrontCountryCode.alpha2(from: "ZZZ") == nil)
    #expect(StorefrontCountryCode.alpha2(from: nil) == nil)
    #expect(StorefrontCountryCode.alpha2(from: "NO") == nil)
    let source = FakeRegionSource("USA")
    let lookup = GatedLookup()
    let service = automaticService(source: source, lookup: lookup)
    let first = Task { try await service.refresh() }
    await lookup.waitForCall("US")
    await lookup.complete("US", version: "2.0")
    _ = try await first.value
    source.change(to: nil)
    let second = Task { try await service.refresh() }
    await lookup.waitForCall("NO")
    await lookup.complete("NO", version: "2.1")
    #expect(try await second.value.release?.version == "2.1")
    source.change(to: "ZZZ")
    #expect(await service.snapshot().release?.version == "2.1")
    #expect(await lookup.countries == ["US", "NO"])
}

@Test func switchingRegionsRestoresSeparateCachesAndRejectsOldResponse() async throws {
    let source = FakeRegionSource("NOR")
    let lookup = GatedLookup()
    let service = automaticService(source: source, lookup: lookup)
    let events = await service.newVersions()
    var eventIterator = events.makeAsyncIterator()
    let old = Task { try await service.refresh() }
    await lookup.waitForCall("NO")
    source.change(to: "USA")
    #expect(await service.snapshot().availability == .unknown)
    let us = Task { try await service.refresh() }
    await lookup.waitForCall("US")
    await lookup.complete("US", version: "3.0")
    #expect(try await us.value.release?.version == "3.0")
    #expect(await eventIterator.next()?.version == "3.0")
    await lookup.complete("NO", version: "2.0")
    do { _ = try await old.value; Issue.record("Old region should be superseded") }
    catch { #expect(error is CancellationError) }
    #expect(await service.snapshot().release?.version == "3.0")
    source.change(to: "NOR")
    #expect(await service.snapshot().release?.version == "2.0")
    _ = try await service.refresh()
    #expect(await eventIterator.next()?.version == "2.0")
    source.change(to: "USA")
    #expect(await service.snapshot().release?.version == "3.0")
    #expect(await lookup.countries == ["NO", "US"])
}

@Test func eventsAreDeduplicatedPerRegionAcrossRestarts() async throws {
    let suite = temporarySuiteName()
    let source = FakeRegionSource("NOR")
    let lookup = StubLookup(result: .success(release("2.0")))
    let service = automaticService(source: source, lookup: lookup, suite: suite)
    let events = await service.newVersions()
    var iterator = events.makeAsyncIterator()
    _ = try await service.refresh()
    #expect(await iterator.next()?.version == "2.0")
    source.change(to: "USA")
    _ = try await service.refresh()
    #expect(await iterator.next()?.version == "2.0")
    source.change(to: "NOR")
    _ = try await service.refresh(force: true)
    let restarted = automaticService(source: source, lookup: lookup, suite: suite)
    _ = try await restarted.refresh()
    let store = UserDefaultsUpdateCacheStore(suiteName: suite)
    let norwegianCache = SagaUpdateRepository(appStoreID: 123, countryCode: "NO", lookup: lookup, store: store)
    let usCache = SagaUpdateRepository(appStoreID: 123, countryCode: "US", lookup: lookup, store: store)
    #expect(!(await norwegianCache.reportIfNew(version: "2.0")))
    #expect(!(await usCache.reportIfNew(version: "2.0")))
    #expect(await lookup.calls == 3)
}

@Test func activeMonitorRechecksNewRegionWithoutPublishingOldResult() async throws {
    let source = FakeRegionSource("NOR")
    let lookup = GatedLookup()
    let service = automaticService(source: source, lookup: lookup)
    await service.setActive(true)
    await source.waitForRegistrations(1)
    await lookup.waitForCall("NO")
    source.change(to: "USA")
    await lookup.waitForCall("US")
    await lookup.complete("NO", version: "2.0")
    await lookup.complete("US", version: "3.0")
    for _ in 0..<200 where await service.snapshot().release?.version != "3.0" { await Task.yield() }
    #expect(await service.snapshot().release?.version == "3.0")
    #expect(source.registrationCount == 1)
    await service.setActive(false)
}

@Test func cancelledRefreshDoesNotPublishFailureOrNewVersion() async throws {
    let source = FakeRegionSource("NOR")
    let lookup = GatedLookup()
    let service = automaticService(source: source, lookup: lookup)
    let refresh = Task { try await service.refresh() }
    await lookup.waitForCall("NO")
    refresh.cancel()
    await lookup.complete("NO", version: "2.0")
    do { _ = try await refresh.value; Issue.record("Expected cancellation") }
    catch { #expect(error is CancellationError) }
    let state = await service.snapshot()
    #expect(state.availability == .unknown)
    #expect(state.lastError == nil)
}

@Test func monitoringHasOneObserverAndStopsOnDeactivation() async throws {
    let source = FakeRegionSource("NOR")
    let lookup = GatedLookup()
    let service = automaticService(source: source, lookup: lookup)
    await service.setActive(true)
    await service.setActive(true)
    await source.waitForRegistrations(1)
    #expect(source.observerCount == 1)
    #expect(source.registrationCount == 1)
    await lookup.waitForCall("NO")
    await service.setActive(false)
    await lookup.complete("NO", version: "2.0")
    for _ in 0..<100 where source.observerCount != 0 { await Task.yield() }
    #expect(source.observerCount == 0)
    #expect(await service.snapshot().availability == .unknown)
    await service.setActive(true)
    await source.waitForRegistrations(2)
    #expect(source.registrationCount == 2)
    await service.setActive(false)
}
