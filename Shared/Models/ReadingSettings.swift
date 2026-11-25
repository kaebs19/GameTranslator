/// How the camera translates and how results look.
nonisolated struct ReadingSettings: Equatable, Sendable {
    enum TextSize: String, CaseIterable, Sendable {
        case small, medium, large
    }

    enum Speed: String, CaseIterable, Sendable {
        /// Waits for two readings to agree.
        case balanced
        /// Shows the first clear reading.
        case fast
    }

    var speed = Speed.balanced
    /// Off: stops by itself after one result.
    var isContinuous = true
    var showsOriginal = true
    var textSize = TextSize.medium
    var savesHistory = true
}
