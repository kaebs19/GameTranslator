import Foundation

/// A hand-held camera reads slightly different text in every frame. New text is accepted
/// once two frames agree (or at once when the caller trusts the frame), and kept until the text really changes or is gone for a moment.
nonisolated struct TextStabilizer {
    /// Frames without text before the result is cleared.
    static let emptyFramesToClear = 4

    private(set) var current: [String] = []
    /// Whether a second frame has agreed with `current`.
    private(set) var isConfirmed = false
    private var candidate: [String] = []
    private var emptyFrames = 0

    /// Returns the new text when it changed, `nil` when nothing should happen.
    mutating func update(_ texts: [String], isTrusted: Bool = false) -> [String]? {
        guard !texts.isEmpty else { return updateEmpty() }
        emptyFrames = 0
        if Self.isSame(texts, current) {
            candidate = []
            isConfirmed = true
            return nil
        }
        let agrees = Self.isSame(texts, candidate)
        guard agrees || isTrusted else {
            candidate = texts
            return nil
        }
        candidate = []
        current = texts
        isConfirmed = agrees
        return texts
    }

    mutating func reset() { self = TextStabilizer() }

    private mutating func updateEmpty() -> [String]? {
        candidate = []
        emptyFrames += 1
        guard emptyFrames >= Self.emptyFramesToClear, !current.isEmpty else { return nil }
        current = []
        isConfirmed = false
        return []
    }

    /// Fuzzy, ignoring order and small recognition errors.
    private static func isSame(_ a: [String], _ b: [String]) -> Bool {
        guard a.count == b.count, !a.isEmpty else { return false }
        var known = TextDeduper()
        known.merge(b)
        return a.allSatisfy { known.contains($0) }
    }
}
