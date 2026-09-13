import SwiftUI

private struct SagaUpdateMonitoringModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    let service: SagaUpdateService

    func body(content: Content) -> some View {
        content
            .task { await service.setActive(scenePhase == .active) }
            .onChange(of: scenePhase) { _, phase in
                Task { await service.setActive(phase == .active) }
            }
            .onDisappear {
                Task { await service.setActive(false) }
            }
    }
}

public extension View {
    /// Attach once at the host app's root view to keep Saga's update checks active.
    func sagaUpdateMonitoring(_ service: SagaUpdateService) -> some View {
        modifier(SagaUpdateMonitoringModifier(service: service))
    }
}
