/// How translations look on a TV, and whether they are sent there at all.
nonisolated struct TVSettings: Equatable, Sendable {
    enum Position: String, CaseIterable, Codable, Sendable {
        case top, bottom
    }

    /// Off by default: nothing listens on the network until the user asks.
    var isEnabled = false
    /// Away from subtitles, which games draw at the bottom and the camera reads.
    var position = Position.top
    var textSize = ReadingSettings.TextSize.medium
    var showsOriginal = false
}
