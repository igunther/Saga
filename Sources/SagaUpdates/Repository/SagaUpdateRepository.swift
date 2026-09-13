import Foundation

struct StoreReleaseModel: Codable, Sendable {
    let version: String
    let storeURL: URL
}

enum StoreReleaseModelMapper {
    static func map(_ dto: AppStoreReleaseDTO) -> StoreReleaseModel {
        StoreReleaseModel(version: dto.version, storeURL: dto.trackViewUrl)
    }
}

struct CachedStoreRelease: Codable, Sendable {
    var release: StoreReleaseModel?
    var checkedAt: Date?
    var lastAttemptAt: Date?
    var lastReportedVersion: String?
}

struct RepositoryCheckResult: Sendable {
    let release: StoreReleaseModel
    let checkedAt: Date
    let fetched: Bool
}

enum SagaUpdateRepositoryError: Error, Equatable, Sendable {
    case appUnavailable
    case invalidResponse
    case networkUnavailable
    case retryDeferred
}

actor SagaUpdateRepository {
    private let lookup: any AppStoreLooking
    private let store: any UpdateCacheStoring
    private let key: String
    private var cache: CachedStoreRelease
    private var inFlight: Task<RepositoryCheckResult, Error>?

    init(appStoreID: Int, countryCode: String, lookup: any AppStoreLooking, store: any UpdateCacheStoring) {
        self.lookup = lookup
        self.store = store
        self.key = "SagaUpdates.\(appStoreID).\(countryCode)"
        if let data = store.load(forKey: key),
           let decoded = try? JSONDecoder().decode(CachedStoreRelease.self, from: data) {
            self.cache = decoded
        } else {
            self.cache = CachedStoreRelease()
        }
    }

    func cachedRelease() -> (StoreReleaseModel, Date)? {
        guard let release = cache.release, let checkedAt = cache.checkedAt else { return nil }
        return (release, checkedAt)
    }

    func nextCheckDate(checkInterval: TimeInterval, retryInterval: TimeInterval) -> Date {
        let interval = cache.checkedAt == cache.lastAttemptAt ? checkInterval : retryInterval
        guard let attempt = cache.lastAttemptAt else { return .distantPast }
        return attempt.addingTimeInterval(interval)
    }

    func check(
        appStoreID: Int,
        countryCode: String,
        checkInterval: TimeInterval,
        retryInterval: TimeInterval,
        now: Date,
        force: Bool = false
    ) async throws -> RepositoryCheckResult {
        if let inFlight {
            return try await inFlight.value
        }
        if !force, now < nextCheckDate(checkInterval: checkInterval, retryInterval: retryInterval) {
            if let release = cache.release, let checkedAt = cache.checkedAt {
                return RepositoryCheckResult(release: release, checkedAt: checkedAt, fetched: false)
            }
            throw SagaUpdateRepositoryError.retryDeferred
        }
        let task = Task {
            try await performLookup(appStoreID: appStoreID, countryCode: countryCode, now: now)
        }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }

    private func performLookup(appStoreID: Int, countryCode: String, now: Date) async throws -> RepositoryCheckResult {
        do {
            let dto = try await lookup.lookup(appStoreID: appStoreID, countryCode: countryCode)
            let release = StoreReleaseModelMapper.map(dto)
            cache.release = release
            cache.checkedAt = now
            cache.lastAttemptAt = now
            persist()
            return RepositoryCheckResult(release: release, checkedAt: now, fetched: true)
        } catch {
            if error is CancellationError { throw error }
            cache.lastAttemptAt = now
            persist()
            switch error {
            case AppStoreLookupError.unavailable: throw SagaUpdateRepositoryError.appUnavailable
            case AppStoreLookupError.invalidResponse: throw SagaUpdateRepositoryError.invalidResponse
            default: throw SagaUpdateRepositoryError.networkUnavailable
            }
        }
    }

    func reportIfNew(version: String) -> Bool {
        guard cache.lastReportedVersion != version else { return false }
        cache.lastReportedVersion = version
        persist()
        return true
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        store.save(data, forKey: key)
    }
}
