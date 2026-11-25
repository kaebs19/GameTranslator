import Foundation

/// Wakes the other process; carries no data.
nonisolated enum DarwinNotification {
    static var liveUpdate: String { "\(AppGroup.identifier).live.update" }

    static func post(_ name: String) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(name as CFString), nil, nil, true
        )
    }

    /// Emits once for every post until the stream is cancelled.
    static func stream(_ name: String) -> AsyncStream<Void> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let observer = Observer(name: name) { continuation.yield() }
            // Callbacks arrive on the main run loop, so removing there cannot race with one.
            continuation.onTermination = { _ in DispatchQueue.main.async { observer.stop() } }
        }
    }

    private final class Observer: Sendable {
        private let handler: @Sendable () -> Void

        init(name: String, handler: @escaping @Sendable () -> Void) {
            self.handler = handler
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(), Unmanaged.passUnretained(self).toOpaque(),
                { _, pointer, _, _, _ in
                    guard let pointer else { return }
                    Unmanaged<Observer>.fromOpaque(pointer).takeUnretainedValue().handler()
                },
                name as CFString, nil, .deliverImmediately
            )
        }

        func stop() {
            CFNotificationCenterRemoveEveryObserver(
                CFNotificationCenterGetDarwinNotifyCenter(), Unmanaged.passUnretained(self).toOpaque()
            )
        }
    }
}
