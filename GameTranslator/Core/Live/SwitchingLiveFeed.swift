import Foundation

/// Uses in-app capture when the user turned it on, the broadcast extension otherwise.
final class SwitchingLiveFeed: LiveFeed {
    private let broadcast: any LiveFeed
    private let inApp: any LiveFeed
    private let settings: any SettingsStoring

    init(broadcast: any LiveFeed, inApp: any LiveFeed, settings: any SettingsStoring) {
        self.broadcast = broadcast
        self.inApp = inApp
        self.settings = settings
    }

    private var active: any LiveFeed { settings.load().live.usesScreenCapture ? inApp : broadcast }

    var isAvailable: Bool { active.isAvailable }
    var readableLanguages: Set<AppLanguage> { active.readableLanguages }
    var capture: (any CaptureControlling)? { active.capture }
    func drain() -> [LiveBatch] { active.drain() }
    func isRunning() -> Bool { active.isRunning() }
    func control() -> LiveControl { active.control() }
    func setPaused(_ isPaused: Bool) { active.setPaused(isPaused) }
    func clear() { active.clear() }

    /// Both, because the choice may change while someone is listening.
    func updates() -> AsyncStream<Void> {
        let streams = [broadcast.updates(), inApp.updates()]
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let tasks = streams.map { stream in
                Task { for await _ in stream { continuation.yield() } }
            }
            continuation.onTermination = { _ in tasks.forEach { $0.cancel() } }
        }
    }

    func settingsDidChange() {
        if !settings.load().live.usesScreenCapture { inApp.capture?.stop() }
        broadcast.settingsDidChange()
        inApp.settingsDidChange()
    }
}
