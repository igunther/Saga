import Foundation

/// Repository-facing region values are lookup-ready alpha-2 country codes.
struct StorefrontRegionRepository: Sendable {
    private let source: any StorefrontRegionSourcing

    init(source: any StorefrontRegionSourcing) { self.source = source }

    func currentCountryCode() async -> String? {
        StorefrontCountryCode.alpha2(from: await source.currentCountryCode())
    }

    func countryCodeUpdates() -> AsyncStream<String?> {
        AsyncStream { continuation in
            let task = Task {
                for await rawCode in source.countryCodeUpdates() {
                    guard !Task.isCancelled else { break }
                    continuation.yield(StorefrontCountryCode.alpha2(from: rawCode))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
