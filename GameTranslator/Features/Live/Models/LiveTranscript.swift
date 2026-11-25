import Foundation

/// Running list of lines seen during one broadcast.
nonisolated struct LiveTranscript {
    struct Line: Identifiable, Equatable {
        let id: UUID
        var original: String
        var translation: String?
        var date: Date
    }

    /// Games often type text out letter by letter; a line that grows within this time is one line.
    static let growthWindow: TimeInterval = 4
    private static let minimumGrowthPrefix = 6

    private(set) var lines: [Line] = []
    private var sessionID: UUID?
    private var deduper: TextDeduper
    private let capacity: Int

    init(capacity: Int = 500) {
        self.capacity = capacity
        deduper = TextDeduper(capacity: capacity)
    }

    /// A new broadcast starts a new transcript.
    mutating func append(_ batch: LiveBatch) {
        if sessionID != batch.sessionID {
            sessionID = batch.sessionID
            lines = []
            deduper.reset()
        }
        // Lines of one batch were on screen together, so they cannot be growths of each other.
        let earlier = lines.count
        for text in deduper.merge(batch.lines) {
            if let index = growingLineIndex(for: text, at: batch.date, within: earlier) {
                lines[index].original = text
                lines[index].translation = nil
                lines[index].date = batch.date
            } else {
                lines.append(Line(id: UUID(), original: text, translation: nil, date: batch.date))
            }
        }
        lines.removeFirst(max(0, lines.count - capacity))
    }

    /// The same broadcast goes on, starting from nothing.
    mutating func clear() {
        lines = []
        deduper.reset()
    }

    func latestTranslations(_ count: Int) -> [String] {
        Array(lines.compactMap(\.translation).suffix(count))
    }

    var untranslated: [String] {
        lines.filter { $0.translation == nil }.map(\.original)
    }

    mutating func apply(_ translations: [String: String]) {
        for index in lines.indices {
            if let translation = translations[lines[index].original] { lines[index].translation = translation }
        }
    }

    private func growingLineIndex(for text: String, at date: Date, within count: Int) -> Int? {
        let key = TextNormalizer.comparisonKey(text)
        return lines.prefix(count).indices.last { index in
            guard date.timeIntervalSince(lines[index].date) <= Self.growthWindow else { return false }
            let previous = TextNormalizer.comparisonKey(lines[index].original)
            return previous.count >= Self.minimumGrowthPrefix && key.count > previous.count && key.hasPrefix(previous)
        }
    }
}
