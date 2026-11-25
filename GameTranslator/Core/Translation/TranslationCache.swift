import Foundation

/// Remembers translations in memory and on disk so no string is translated twice.
actor TranslationCache {
    private let fileURL: URL
    private let capacity: Int
    private var storage: [String: String] = [:]
    /// Oldest first; used to evict once `capacity` is reached.
    private var order: [String] = []
    private var isLoaded = false

    private struct Snapshot: Codable {
        let order: [String]
        let storage: [String: String]
    }

    init(fileURL: URL = TranslationCache.defaultFileURL, capacity: Int = 5000) {
        self.fileURL = fileURL
        self.capacity = capacity
    }

    static var defaultFileURL: URL {
        URL.applicationSupportDirectory.appending(path: "translation-cache.json")
    }

    func translation(for text: String, pair: LanguagePair) -> String? {
        loadIfNeeded()
        return storage[Self.key(text, pair)]
    }

    func translations(for texts: [String], pair: LanguagePair) -> [String: String] {
        loadIfNeeded()
        var found: [String: String] = [:]
        for text in texts { found[text] = storage[Self.key(text, pair)] }
        return found
    }

    func store(_ translations: [String: String], pair: LanguagePair) {
        guard !translations.isEmpty else { return }
        loadIfNeeded()
        for (text, translated) in translations {
            let key = Self.key(text, pair)
            if storage.updateValue(translated, forKey: key) == nil { order.append(key) }
        }
        evictIfNeeded()
        save()
    }

    func clear() {
        storage = [:]
        order = []
        isLoaded = true
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Spacing is ignored but case is kept: "Polish" and "polish" translate differently.
    private static func key(_ text: String, _ pair: LanguagePair) -> String {
        "\(pair.source)>\(pair.target)|\(TextNormalizer.collapsingWhitespace(text))"
    }

    private func evictIfNeeded() {
        let overflow = order.count - capacity
        guard overflow > 0 else { return }
        for key in order.prefix(overflow) { storage[key] = nil }
        order.removeFirst(overflow)
    }

    private func loadIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        storage = snapshot.storage
        order = snapshot.order
    }

    /// A failed save only costs a repeated translation, so it is not surfaced.
    private func save() {
        guard let data = try? JSONEncoder().encode(Snapshot(order: order, storage: storage)) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        var url = fileURL
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }
}
