import CoreGraphics

/// What the user should know about the box right now.
nonisolated enum ReadingStatus: Equatable, Sendable {
    case paused, searching, reading, moveCloser, noText
}

nonisolated struct ReadingStatusTracker {
    /// Text smaller than this in camera pixels is read with many mistakes.
    static let minimumTextHeight: CGFloat = 16
    private static let emptyReadings = 3

    private var empty = 0

    mutating func status(for reading: CameraReading) -> ReadingStatus {
        let heights = reading.lines
            .filter { TextNormalizer.looksLikeText($0.text) }
            .map { $0.boundingBox.height * reading.pixelHeight }
            .sorted()
        guard !heights.isEmpty else {
            empty += 1
            return reading.isStill || empty >= Self.emptyReadings ? .noText : .searching
        }
        empty = 0
        return heights[heights.count / 2] < Self.minimumTextHeight ? .moveCloser : .reading
    }

    mutating func reset() { empty = 0 }
}
