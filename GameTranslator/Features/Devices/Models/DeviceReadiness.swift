import Foundation

/// What the My Devices screen shows at the top: is everything set for playing?
struct DeviceReadiness: Equatable {
    enum Level: Equatable { case ready, attention, off }

    var isBroadcasting = false
    var pairedTVs = 0
    var connectedTVs = 0
    var usesEnhancedTranslation = false

    /// The camera works on its own; broadcasting is shown when it runs.
    var reading: Level { .ready }

    var tv: Level {
        if pairedTVs == 0 { return .off }
        return connectedTVs > 0 ? .ready : .attention
    }

    var enhanced: Level { usesEnhancedTranslation ? .ready : .off }
}
