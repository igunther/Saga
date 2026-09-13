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
