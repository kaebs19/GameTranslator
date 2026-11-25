import Foundation
import Observation

/// Where finished translations are reported.
protocol HistoryRecording: AnyObject {
    /// Keyed by original text. Order is the order on screen.
    func record(_ translations: [(original: String, translation: String)], pair: LanguagePair, source: HistoryEntry.Source)
}

/// Newest first, kept in a protected file on this device.
@Observable
final class HistoryStore: HistoryRecording {
    static let capacity = 1000

    private(set) var entries: [HistoryEntry]

    private let fileURL: URL
    private let settings: any SettingsStoring
    private let now: () -> Date

    init(
        fileURL: URL = URL.applicationSupportDirectory.appending(path: "history.json"),
        settings: any SettingsStoring, now: @escaping () -> Date = { Date() }
    ) {
        self.fileURL = fileURL
        self.settings = settings
        self.now = now
        entries = Self.read(fileURL)
    }

    func record(
        _ translations: [(original: String, translation: String)], pair: LanguagePair, source: HistoryEntry.Source
    ) {
        guard settings.load().reading.savesHistory, !translations.isEmpty else { return }
        for item in translations.reversed() {
            // Seeing the same text again moves it up instead of repeating it.
            entries.removeAll { $0.original == item.original && $0.pair == pair }
            entries.insert(HistoryEntry(
                id: UUID(), original: item.original, translation: item.translation,
                pair: pair, source: source, date: now()
            ), at: 0)
        }
        entries.removeLast(max(0, entries.count - Self.capacity))
        save()
    }

    func remove(_ id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    func clear() {
        entries = []
        try? FileManager.default.removeItem(at: fileURL)
    }

    private static func read(_ url: URL) -> [HistoryEntry] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([HistoryEntry].self, from: data)) ?? []
    }

    /// A failed save loses history, not a translation, so it is not surfaced.
    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        var url = fileURL
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }
}
