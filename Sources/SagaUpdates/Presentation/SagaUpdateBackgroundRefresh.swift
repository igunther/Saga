#if os(iOS)
import BackgroundTasks
import Foundation
import OSLog

private let updateBackgroundLogger = Logger(subsystem: "SagaUpdates", category: "BackgroundRefresh")

public enum SagaUpdateBackgroundError: Error, Sendable {
    case notConfigured
}

public extension SagaUpdateService {
    /// Schedule an opportunistic iOS refresh. The host must configure the identifier and
    /// register a matching SwiftUI `.backgroundTask(.appRefresh(identifier))` handler.
    func scheduleBackgroundRefresh() async throws {
        guard let identifier = configuration.backgroundTaskIdentifier else {
            throw SagaUpdateBackgroundError.notConfigured
        }
        let due = await nextCheckDate()
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = max(due, Date().addingTimeInterval(60))
        try BGTaskScheduler.shared.submit(request)
    }

    /// Call from the host scene's registered app-refresh handler.
    func performBackgroundRefresh() async {
        do {
            try await refresh()
        } catch is CancellationError {
            return
        } catch {
            updateBackgroundLogger.error("App Store version check failed: \(String(describing: error))")
        }
        do {
            try await scheduleBackgroundRefresh()
        } catch {
            updateBackgroundLogger.error("Scheduling update refresh failed: \(String(describing: error))")
        }
    }
}
#endif
