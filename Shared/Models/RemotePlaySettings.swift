import CoreGraphics

/// Playing through a remote-play app on this phone, with translations sent to the TV through the server.
nonisolated struct RemotePlaySettings: Equatable, Sendable {
    /// The broadcast reads only this part of the game picture: where the game shows its subtitles.
    /// Normalized, top-left origin, as the picture is seen upright.
    var region = RemotePlaySettings.subtitles
    /// On while set up: the broadcast then sends to the TV instead of only to this app.
    var sendsToTV = false

    /// Where most games put subtitles.
    static let subtitles = CGRect(x: 0.1, y: 0.72, width: 0.8, height: 0.22)

    /// Kept usable: not empty, inside the picture.
    static func clamped(_ rect: CGRect) -> CGRect {
        let width = min(max(rect.width, 0.1), 1)
        let height = min(max(rect.height, 0.05), 1)
        return CGRect(
            x: min(max(rect.minX, 0), 1 - width), y: min(max(rect.minY, 0), 1 - height), width: width, height: height
        )
    }
}
