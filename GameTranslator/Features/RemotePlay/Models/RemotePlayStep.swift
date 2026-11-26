import Foundation

/// Playing a console game through its remote-play app, with the translation over the game on the TV.
/// Each step opens only when the one before is done.
enum RemotePlayStep: Int, CaseIterable {
    case console, remoteApp, tvApp, pair, region, broadcast, play, done

    /// Steps the app cannot see happen; the user says when they are done.
    var needsConfirmation: Bool {
        switch self {
        case .console, .remoteApp, .tvApp, .region: true
        default: false
        }
    }
}

/// What tells each step it is done.
struct RemotePlayProgress: Equatable {
    var confirmed: Set<RemotePlayStep> = []
    var isTVConnected = false
    var isBroadcasting = false
    /// Lines read since the play step began.
    var linesRead = 0

    func isDone(_ step: RemotePlayStep) -> Bool {
        switch step {
        case .console, .remoteApp, .tvApp, .region: confirmed.contains(step)
        case .pair: isTVConnected
        case .broadcast: isBroadcasting
        case .play: linesRead > 0 || confirmed.contains(.play)
        case .done: true
        }
    }
}
