import Foundation

public enum SagaUpdateRegion: Sendable, Equatable {
    /// Always query this two-letter App Store country, independent of StoreKit.
    case countryCode(String)
    /// Follow the App Store storefront; use the two-letter fallback if unavailable or unknown.
    case automatic(fallbackCountryCode: String)
}

public struct SagaUpdateConfiguration: Sendable {
    public let appStoreID: Int
    public let installedVersion: String
    /// The explicit country, or the fallback in automatic mode (retained for source compatibility).
    public let countryCode: String
    public let region: SagaUpdateRegion
    public let checkInterval: TimeInterval
    public let retryInterval: TimeInterval
    /// Optional iOS BGAppRefreshTask identifier registered by the host app.
    public let backgroundTaskIdentifier: String?

    public init(
        appStoreID: Int,
        installedVersion: String,
        countryCode: String,
        checkInterval: TimeInterval = 24 * 60 * 60,
        retryInterval: TimeInterval = 60 * 60,
        backgroundTaskIdentifier: String? = nil
    ) {
        self.init(appStoreID: appStoreID, installedVersion: installedVersion,
                  region: .countryCode(countryCode), checkInterval: checkInterval,
                  retryInterval: retryInterval, backgroundTaskIdentifier: backgroundTaskIdentifier)
    }

    public init(
        appStoreID: Int,
        installedVersion: String,
        region: SagaUpdateRegion,
        checkInterval: TimeInterval = 24 * 60 * 60,
        retryInterval: TimeInterval = 60 * 60,
        backgroundTaskIdentifier: String? = nil
    ) {
        precondition(appStoreID > 0)
        precondition(checkInterval.isFinite && checkInterval > 0)
        precondition(retryInterval.isFinite && retryInterval > 0)
        let countryCode: String
        switch region {
        case .countryCode(let code), .automatic(let code): countryCode = code
        }
        let normalizedCountry = countryCode.uppercased()
        precondition(normalizedCountry.utf8.count == 2 && normalizedCountry.utf8.allSatisfy { $0 >= 65 && $0 <= 90 })
        if let backgroundTaskIdentifier { precondition(!backgroundTaskIdentifier.isEmpty) }
        self.appStoreID = appStoreID
        self.installedVersion = installedVersion
        self.countryCode = normalizedCountry
        switch region {
        case .countryCode: self.region = .countryCode(normalizedCountry)
        case .automatic: self.region = .automatic(fallbackCountryCode: normalizedCountry)
        }
        self.checkInterval = checkInterval
        self.retryInterval = retryInterval
        self.backgroundTaskIdentifier = backgroundTaskIdentifier
    }
}

public struct SagaStoreRelease: Equatable, Sendable {
    public let version: String
    public let storeURL: URL

    public init(version: String, storeURL: URL) {
        self.version = version
        self.storeURL = storeURL
    }
}

enum SagaStoreReleaseMapper {
    static func map(_ model: StoreReleaseModel) -> SagaStoreRelease {
        SagaStoreRelease(version: model.version, storeURL: model.storeURL)
    }
}

public enum SagaUpdateAvailability: Equatable, Sendable {
    case unknown
    case upToDate
    case updateAvailable
}

public enum SagaUpdateError: Error, Equatable, Sendable {
    case invalidInstalledVersion
    case invalidStoreResponse
    case appUnavailable
    case networkUnavailable
}

public struct SagaUpdateSnapshot: Equatable, Sendable {
    public let release: SagaStoreRelease?
    public let availability: SagaUpdateAvailability
    public let checkedAt: Date?
    public let lastError: SagaUpdateError?

    public init(
        release: SagaStoreRelease?,
        availability: SagaUpdateAvailability,
        checkedAt: Date?,
        lastError: SagaUpdateError? = nil
    ) {
        self.release = release
        self.availability = availability
        self.checkedAt = checkedAt
        self.lastError = lastError
    }
}

enum SagaVersion: Comparable {
    case components([Int])

    init?(_ raw: String) {
        let parts = raw.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isASCIIDigit) }) else {
            return nil
        }
        let numbers = parts.compactMap { Int($0) }
        guard numbers.count == parts.count else { return nil }
        self = .components(numbers)
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        guard case let .components(left) = lhs, case let .components(right) = rhs else { return false }
        for index in 0..<max(left.count, right.count) {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0
            if a != b { return a < b }
        }
        return false
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}

private extension Character {
    var isASCIIDigit: Bool { asciiValue.map { $0 >= 48 && $0 <= 57 } ?? false }
}
