import Foundation

/// Lines that appeared together in one frame.
nonisolated struct LiveBatch: Codable, Equatable, Sendable {
    /// Identifies one broadcast, from start to stop.
    let sessionID: UUID
    let sequence: Int
    let date: Date
    let lines: [String]
}

/// Written by the app to steer a running broadcast.
nonisolated struct LiveControl: Codable, Equatable, Sendable {
    var isPaused = false
    /// Raised by every "clear", so the extension forgets what it has seen.
    var generation = 0
}

/// Written by the extension so the app knows whether it is running.
nonisolated struct LiveStatus: Codable, Equatable, Sendable {
    /// Longer than the write interval; covers the extension being killed without notice.
    static let staleAfter: TimeInterval = 12
    static let heartbeatInterval: TimeInterval = 4

    var sessionID: UUID
    var isRunning: Bool
    var heartbeat: Date

    func isActive(at date: Date = .now) -> Bool {
        isRunning && date.timeIntervalSince(heartbeat) < Self.staleAfter
    }
}
