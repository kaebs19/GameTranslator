import Foundation

/// A hand-held camera reads slightly different text in every frame. Each frame is first combined
/// with the last few (`TextFusion`), so one misread word is outvoted. A line is accepted once two
/// frames agree on it (or at once when the caller trusts the frame), and kept until the text
/// really changes or is gone for a while. While the frames that follow agree, the accepted text
/// may still be corrected a few times.
nonisolated struct TextStabilizer {
    /// How long text may go unread before it counts as gone.
    static let holdTime: TimeInterval = 4
    /// Frames combined into each reading.
    static let fusedFrames = 5
    /// Corrections of one accepted text. Each one is translated again.
    static let maximumCorrections = 2

    private(set) var current: [String] = []
    /// Whether a second frame has agreed with `current`.
    private(set) var isConfirmed = false
    private var last: [String] = []
    private var missingSince: TimeInterval?
    /// Newest last.
    private var recent: [[String]] = []
    private var corrections = 0

    /// Returns the new text when it changed, `nil` when nothing should happen.
    mutating func update(_ read: [String], isTrusted: Bool = false, at now: TimeInterval) -> [String]? {
        let texts = fused(read)
        let previous = last
        last = texts
        if Self.isSame(texts, current) {
            missingSince = nil
            // Two frames in a row now read it better.
            if texts != current, texts == previous, corrections < Self.maximumCorrections {
                corrections += 1
                current = texts
                isConfirmed = false
                return texts
            }
            isConfirmed = isConfirmed || !current.isEmpty
            return nil
        }
        if Self.isPart(texts, of: current), isHeld(at: now) { return nil }
        guard !texts.isEmpty else { return clear() }
        // One line that reads differently every time must not hold back the others.
        let agreed = Self.common(texts, previous)
        let accepted = isTrusted ? texts : agreed
        guard !accepted.isEmpty else { return nil }
        if !Self.isPart(texts, of: current) {
            if Self.isSame(accepted, current) {
                missingSince = nil
                isConfirmed = true
                return nil
            }
            if Self.isPart(accepted, of: current), isHeld(at: now) { return nil }
        }
        missingSince = nil
        corrections = 0
        current = accepted
        isConfirmed = agreed.count == accepted.count
        return accepted
    }

    mutating func reset() { self = TextStabilizer() }

    /// Each text voted on with its versions in the last frames.
    private mutating func fused(_ texts: [String]) -> [String] {
        let earlier = recent
        recent = Array((recent + [texts]).suffix(Self.fusedFrames))
        return texts.map { text in
            let versions = earlier.reversed().compactMap { frame in
                frame.map { ($0, TextFusion.similarity($0, text)) }
                    .filter { $0.1 >= TextFusion.minimumSimilarity }
                    .max { $0.1 < $1.1 }?.0
            }
            return TextFusion.fused([text] + versions)
        }
    }

    private mutating func isHeld(at now: TimeInterval) -> Bool {
        let start = missingSince ?? now
        missingSince = start
        return now - start < Self.holdTime
    }

    private mutating func clear() -> [String]? {
        guard !current.isEmpty else { return nil }
        let frames = recent
        reset()
        recent = frames
        return []
    }

    /// Fuzzy, ignoring order and small recognition errors.
    private static func isSame(_ a: [String], _ b: [String]) -> Bool {
        a.count == b.count && isPart(a, of: b)
    }

    private static func isPart(_ part: [String], of whole: [String]) -> Bool {
        common(part, whole).count == part.count
    }

    /// The lines of `a` that are also in `b`.
    private static func common(_ a: [String], _ b: [String]) -> [String] {
        var known = TextDeduper()
        known.merge(b)
        return a.filter { known.contains($0) }
    }
}
