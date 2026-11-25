import Foundation
import Observation

@Observable
final class HistoryViewModel {
    struct Day: Identifiable {
        let date: Date
        let entries: [HistoryEntry]
        var id: Date { date }
    }

    var query = ""
    /// `nil` shows everything.
    var source: HistoryEntry.Source?

    private let store: HistoryStore
    private let calendar: Calendar

    init(store: HistoryStore, calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
    }

    var isEmpty: Bool { store.entries.isEmpty }

    var days: [Day] {
        let groups = Dictionary(grouping: matches) { calendar.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { Day(date: $0, entries: groups[$0] ?? []) }
    }

    func remove(_ entry: HistoryEntry) { store.remove(entry.id) }

    func clear() { store.clear() }

    private var matches: [HistoryEntry] {
        let text = TextNormalizer.collapsingWhitespace(query)
        return store.entries.filter { entry in
            (source == nil || entry.source == source)
                && (text.isEmpty || entry.original.localizedStandardContains(text)
                    || entry.translation.localizedStandardContains(text))
        }
    }
}
