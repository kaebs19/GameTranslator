import UserNotifications

protocol NotificationProviding {
    /// Asks the user once; later calls return the earlier answer.
    func requestPermission() async -> Bool
    func show(title: String, body: String)
    func removeDelivered()
}

struct SystemNotificationService: NotificationProviding {
    func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])) ?? false
    }

    func show(title: String, body: String) { LiveNotification.post(title: title, body: body) }

    func removeDelivered() { LiveNotification.remove() }
}

/// Opens the live screen when the banner is tapped.
nonisolated final class NotificationTapHandler: NSObject, UNUserNotificationCenterDelegate {
    private let onTap: @MainActor @Sendable () -> Void

    init(onTap: @escaping @MainActor @Sendable () -> Void) {
        self.onTap = onTap
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        guard response.notification.request.identifier == LiveNotification.identifier else { return }
        await onTap()
    }
}
