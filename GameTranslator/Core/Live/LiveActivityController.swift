import ActivityKit
import Foundation

protocol LiveActivityControlling: AnyObject {
    func show(_ state: LiveActivityAttributes.ContentState)
    func end()
    /// Returns once everything requested so far has reached the system.
    func flush() async
}

/// Applies changes one at a time and skips the ones already overtaken.
final class SystemLiveActivityController: LiveActivityControlling {
    private enum Command {
        case show(LiveActivityAttributes.ContentState)
        case end
    }

    private var next: Command?
    private var worker: Task<Void, Never>?
    private var lastShown: LiveActivityAttributes.ContentState?
    /// The user may dismiss the activity; do not bring it back in the same broadcast.
    private var didStart = false

    func show(_ state: LiveActivityAttributes.ContentState) {
        if next == nil, let lastShown, lastShown.hasSameContent(as: state) { return }
        run(.show(state))
    }

    func end() { run(.end) }

    func flush() async { await worker?.value }

    private func run(_ command: Command) {
        next = command
        guard worker == nil else { return }
        worker = Task {
            while let command = takeNext() { await apply(command) }
            worker = nil
        }
    }

    private func takeNext() -> Command? {
        defer { next = nil }
        return next
    }

    private func apply(_ command: Command) async {
        switch command {
        case .show(let state):
            if await Self.update(state) {
                didStart = true
                lastShown = state
            } else if !didStart, start(state) {
                didStart = true
                lastShown = state
            }
        case .end:
            await Self.endAll()
            didStart = false
            lastShown = nil
        }
    }

    /// Only succeeds while the app is in the foreground.
    private func start(_ state: LiveActivityAttributes.ContentState) -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
        let activity = try? Activity.request(
            attributes: LiveActivityAttributes(), content: ActivityContent(state: state, staleDate: nil)
        )
        return activity != nil
    }

    @concurrent
    private nonisolated static func update(_ state: LiveActivityAttributes.ContentState) async -> Bool {
        let activities = Activity<LiveActivityAttributes>.activities
        for activity in activities { await activity.update(ActivityContent(state: state, staleDate: nil)) }
        return !activities.isEmpty
    }

    @concurrent
    private nonisolated static func endAll() async {
        for activity in Activity<LiveActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
