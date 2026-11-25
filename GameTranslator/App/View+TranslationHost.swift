import SwiftUI
import Translation

extension View {
    /// Supplies translation sessions to the service. Attach once, near the root.
    func translationHost(_ service: TranslationService) -> some View {
        modifier(TranslationHost(service: service))
    }
}

private struct TranslationHost: ViewModifier {
    let service: TranslationService
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .translationTask(service.configuration) { session in
                await service.drainQueue {
                    try await session.translateAll($0)
                } prepare: {
                    try await session.prepareLanguages()
                }
            }
            // Inactive still shows views: alerts and the download sheet cause it.
            .onChange(of: scenePhase, initial: true) { _, phase in
                service.hostDidChange(isActive: phase != .background)
            }
    }
}
