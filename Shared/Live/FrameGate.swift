import Foundation

/// Lets about one frame per interval through, and never while one is being processed.
nonisolated struct FrameGate: Sendable {
    var interval: TimeInterval
    private var lastStart: TimeInterval?
    private var isBusy = false

    init(interval: TimeInterval = 1) {
        self.interval = interval
    }

    mutating func begin(at time: TimeInterval) -> Bool {
        guard !isBusy else { return false }
        if let lastStart, time - lastStart < interval { return false }
        lastStart = time
        isBusy = true
        return true
    }

    mutating func end() {
        isBusy = false
    }
}
