import Foundation
import StoreKit

/// StoreKit remains at the system boundary; consumers inject this protocol in tests.
protocol StorefrontRegionSourcing: Sendable {
    func currentCountryCode() async -> String?
    func countryCodeUpdates() -> AsyncStream<String?>
}

struct StoreKitRegionSource: StorefrontRegionSourcing {
    func currentCountryCode() async -> String? {
        await Storefront.current?.countryCode
    }

    func countryCodeUpdates() -> AsyncStream<String?> {
        AsyncStream { continuation in
            let task = Task {
                for await storefront in Storefront.updates {
                    guard !Task.isCancelled else { break }
                    continuation.yield(storefront.countryCode)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

enum StorefrontCountryCode {
    /// ICU's ISO region data canonicalizes all known ISO 3166-1 alpha-3 codes.
    /// Reject unknown codes, numeric UN regions, and non-alpha-2 results.
    static func alpha2(from alpha3: String?) -> String? {
        guard let alpha3 else { return nil }
        let code = alpha3.uppercased()
        guard code.utf8.count == 3, code.utf8.allSatisfy({ (65...90).contains($0) }) else { return nil }
        guard let result = Locale(identifier: "und_\(code)").region?.identifier,
              result.utf8.count == 2,
              result.utf8.allSatisfy({ (65...90).contains($0) }),
              Locale.Region.isoRegions.contains(Locale.Region(result)) else { return nil }
        return result
    }
}
