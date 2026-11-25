import Foundation

/// Merges OCR lines into a running transcript and drops lines already seen,
/// so scrolling or re-scanning the same screen does not repeat text.
nonisolated struct TextDeduper: Sendable {
    private struct Entry: Sendable {
        let words: [[Character]]
        let joined: [Character]

        init(_ text: String) {
            words = TextNormalizer.comparisonKey(text).split(separator: " ").map(Array.init)
            joined = Array(words.joined())
        }
    }

    /// 1 means exact matches only.
    let similarityThreshold: Double
    /// How many recent lines are remembered. Bounds memory for live mode.
    let capacity: Int

    private(set) var transcript: [String] = []
    private var entries: [Entry] = []

    init(similarityThreshold: Double = 0.85, capacity: Int = 500) {
        self.similarityThreshold = similarityThreshold
        self.capacity = max(1, capacity)
    }

    /// Appends unseen lines and returns only what was added.
    @discardableResult
    mutating func merge(_ lines: [String]) -> [String] {
        var added: [String] = []
        for line in lines {
            let text = TextNormalizer.collapsingWhitespace(line)
            let entry = Entry(text)
            guard !entry.words.isEmpty, !hasSeen(entry) else { continue }
            entries.append(entry)
            transcript.append(text)
            added.append(text)
        }
        trimToCapacity()
        return added
    }

    func contains(_ line: String) -> Bool {
        hasSeen(Entry(line))
    }

    mutating func reset() {
        transcript.removeAll()
        entries.removeAll()
    }

    private func hasSeen(_ candidate: Entry) -> Bool {
        entries.reversed().contains { isSameLine($0, candidate) }
    }

    /// Compared word by word: over a whole line a few edits could hide a different
    /// word, so "Go to the north gate" would swallow "Go to the south gate".
    private func isSameLine(_ a: Entry, _ b: Entry) -> Bool {
        // Recognition sometimes drops or adds a space.
        if a.joined == b.joined { return true }
        guard a.words.count == b.words.count else { return false }
        return zip(a.words, b.words).allSatisfy(isSameWord)
    }

    private func isSameWord(_ a: [Character], _ b: [Character]) -> Bool {
        if a == b { return true }
        let longest = max(a.count, b.count)
        // Short words and numbers change meaning with a single character.
        guard similarityThreshold < 1, longest > 3, !(a + b).contains(where: \.isNumber) else { return false }
        let allowedEdits = max(1, Int((Double(longest) * (1 - similarityThreshold)).rounded(.down)))
        return EditDistance.isWithin(allowedEdits, a, b)
    }

    private mutating func trimToCapacity() {
        let overflow = transcript.count - capacity
        guard overflow > 0 else { return }
        transcript.removeFirst(overflow)
        entries.removeFirst(overflow)
    }
}

nonisolated enum EditDistance {
    /// Levenshtein distance check that stops as soon as the limit is exceeded.
    static func isWithin(_ limit: Int, _ a: [Character], _ b: [Character]) -> Bool {
        guard abs(a.count - b.count) <= limit else { return false }
        guard !a.isEmpty, !b.isEmpty else { return true }
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i] + Array(repeating: 0, count: b.count)
            var best = i
            for j in 1...b.count {
                let substitution = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)
                current[j] = min(substitution, previous[j] + 1, current[j - 1] + 1)
                best = min(best, current[j])
            }
            if best > limit { return false }
            previous = current
        }
        return previous[b.count] <= limit
    }
}
