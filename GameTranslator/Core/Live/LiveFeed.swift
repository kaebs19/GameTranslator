import Foundation

/// Where live lines come from. A different capture source only needs to implement this.
protocol LiveFeed {
    /// `false` when the app and its extension cannot share data.
    var isAvailable: Bool { get }
    /// Emits whenever it is worth checking again.
    func updates() -> AsyncStream<Void>
    /// Returns pending batches once, oldest first.
    func drain() -> [LiveBatch]
    func isRunning() -> Bool
    func control() -> LiveControl
    func setPaused(_ isPaused: Bool)
    /// Drops pending lines and makes the source forget what it has seen.
    func clear()
    var readableLanguages: Set<AppLanguage> { get }
    /// Present when the app itself starts and stops capture; otherwise the system button does.
    var capture: (any CaptureControlling)? { get }
    func settingsDidChange()
}

protocol CaptureControlling: AnyObject {
    func start()
    func stop()
    /// Returns a failure once.
    func takeError() -> AppError?
}

/// Reads what the broadcast extension wrote to the App Group.
final class AppGroupLiveFeed: LiveFeed {
    private let channel: LiveChannel?

    init(channel: LiveChannel? = .appGroup()) {
        self.channel = channel
    }

    var isAvailable: Bool { channel != nil }

    /// The extension uses fast recognition, which reads fewer languages.
    let readableLanguages = OCRService(mode: .fast).readableLanguages

    var capture: (any CaptureControlling)? { nil }

    func settingsDidChange() {}

    /// Extension notifications, plus a slow tick to notice an extension that died silently.
    func updates() -> AsyncStream<Void> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let notifications = Task {
                for await _ in DarwinNotification.stream(DarwinNotification.liveUpdate) { continuation.yield() }
            }
            let ticks = Task {
                while !Task.isCancelled {
                    continuation.yield()
                    try? await Task.sleep(for: .seconds(LiveStatus.heartbeatInterval))
                }
            }
            continuation.onTermination = { _ in
                notifications.cancel()
                ticks.cancel()
            }
        }
    }

    func drain() -> [LiveBatch] { channel?.drain() ?? [] }

    func isRunning() -> Bool { channel?.status()?.isActive() ?? false }

    func control() -> LiveControl { channel?.control() ?? LiveControl() }

    func setPaused(_ isPaused: Bool) { updateControl { $0.isPaused = isPaused } }

    func clear() {
        updateControl { $0.generation += 1 }
        channel?.removeAllBatches()
    }

    private func updateControl(_ change: (inout LiveControl) -> Void) {
        guard let channel else { return }
        var control = channel.control()
        change(&control)
        try? channel.write(control)
    }
}
