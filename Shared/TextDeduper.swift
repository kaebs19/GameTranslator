import Foundation

/// Merges OCR lines into a running transcript and drops lines already seen,
/// so scrolling or re-scanning the same screen does not repeat text.
nonisolated struct TextDeduper: Sendable {
    private struct Entry: Sendable {
        let key: [Character]
        let digits: [Character]
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
            let key = Array(TextNormalizer.comparisonKey(text))
            guard !key.isEmpty else { continue }
            let entry = Entry(key: key, digits: key.filter(\.isNumber))
            guard !hasSeen(entry) else { continue }
            entries.append(entry)
            transcript.append(text)
            added.append(text)
        }
        trimToCapacity()
        return added
    }

    func contains(_ line: String) -> Bool {
        let key = Array(TextNormalizer.comparisonKey(line))
        return hasSeen(Entry(key: key, digits: key.filter(\.isNumber)))
    }

    mutating func reset() {
        transcript.removeAll()
        entries.removeAll()
    }

    private func hasSeen(_ candidate: Entry) -> Bool {
        entries.reversed().contains { isSameLine($0, candidate) }
    }

    private func isSameLine(_ a: Entry, _ b: Entry) -> Bool {
        if a.key == b.key { return true }
        // "Mission 1" and "Mission 2" are one edit apart but are different lines.
        guard a.digits == b.digits else { return false }
        let longest = max(a.key.count, b.key.count)
        let allowedEdits = Int((Double(longest) * (1 - similarityThreshold) + 1e-9).rounded(.down))
        guard allowedEdits > 0 else { return false }
        return EditDistance.isWithin(allowedEdits, a.key, b.key)
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
