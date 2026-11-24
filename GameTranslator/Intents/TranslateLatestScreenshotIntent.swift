import AppIntents
import UniformTypeIdentifiers

/// Available in Shortcuts, Back Tap and the Action Button.
struct TranslateLatestScreenshotIntent: AppIntent {
    static let title: LocalizedStringResource = "intent.title"
    static let description = IntentDescription("intent.description")
    static let openAppWhenRun = true

    /// Lets a shortcut pass its own "Take Screenshot" result instead of reading Photos.
    @Parameter(title: "intent.image", description: "intent.image.description", supportedContentTypes: [.image])
    var image: IntentFile?

    @MainActor
    func perform() async throws -> some IntentResult {
        if let image {
            AppRouter.shared.open(.image(image.data))
        } else {
            AppRouter.shared.open(.latestScreenshot)
        }
        return .result()
    }
}

struct GameTranslatorShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TranslateLatestScreenshotIntent(),
            phrases: ["Translate latest screenshot with \(.applicationName)"],
            shortTitle: "intent.title",
            systemImageName: "text.viewfinder"
        )
    }
}
