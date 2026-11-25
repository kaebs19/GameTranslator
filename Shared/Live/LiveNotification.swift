import Foundation
import UserNotifications

/// One replaceable banner. Reusing the identifier keeps Notification Center clean.
nonisolated enum LiveNotification {
    static let identifier = "live.update"

    static func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        )
    }

    static func remove() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}

/// Keeps banners from covering the game every second.
nonisolated struct NotificationThrottle: Sendable {
    let interval: TimeInterval
    private var last: TimeInterval?

    init(interval: TimeInterval = 30) {
        self.interval = interval
    }

    mutating func allows(at time: TimeInterval) -> Bool {
        if let last, time - last < interval { return false }
        last = time
        return true
    }
}
