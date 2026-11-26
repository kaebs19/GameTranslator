/// Improved translations from the SubGG server, which replace the on-device ones.
nonisolated struct ServerSettings: Equatable, Sendable {
    enum Style: String, CaseIterable, Sendable {
        /// Modern Standard Arabic.
        case standard
        /// Gulf Arabic, as players speak.
        case gulf
    }

    /// Off by default: nothing leaves the device unless the user turns this on.
    var isEnabled = false
    var style = Style.standard
}
