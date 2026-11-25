/// How live results are shown while another app is on screen.
nonisolated struct LiveSettings: Equatable, Sendable {
    /// Five lines would exceed the 160 points iOS gives a Live Activity.
    static let lineCountRange = 1...4

    var showsLiveActivity = true
    var sendsNotifications = false
    /// Experimental, iOS 27+: capture from the app instead of the broadcast extension.
    var usesScreenCapture = false
    var lineCount = 3 {
        didSet { lineCount = min(max(lineCount, Self.lineCountRange.lowerBound), Self.lineCountRange.upperBound) }
    }
}
