import AppIntents

/// What the Live Activity buttons do. The app sets the handler at launch;
/// the system runs these intents inside the app process, even in the background.
protocol LiveActionHandling: AnyObject {
    func translateNow() async
    func togglePause() async
    func clear() async
}

enum LiveActions {
    static weak var handler: (any LiveActionHandling)?
}

struct TranslateLiveIntent: LiveActivityIntent {
    static let title = LocalizedStringResource("activity.translate", table: "LiveActivity")
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        await LiveActions.handler?.translateNow()
        return .result()
    }
}

struct ToggleLivePauseIntent: LiveActivityIntent {
    static let title = LocalizedStringResource("activity.pause", table: "LiveActivity")
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        await LiveActions.handler?.togglePause()
        return .result()
    }
}

struct ClearLiveIntent: LiveActivityIntent {
    static let title = LocalizedStringResource("activity.clear", table: "LiveActivity")
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        await LiveActions.handler?.clear()
        return .result()
    }
}
