import Foundation

/// Better translations that arrive after the instant on-device ones.
protocol TranslationRefining: AnyObject {
    /// Returns only lines with a better translation; empty when the feature is off or the server
    /// cannot be reached, so callers simply keep what they have.
    /// - Parameter context: Lines read just before, which help the model but are not translated.
    func refined(_ texts: [String], pair: LanguagePair, context: [String]) async -> [String: String]
}

/// Asks the SubGG server, if the user turned it on, and remembers the answers on the device.
final class ServerRefiner: TranslationRefining {
    private let server: any ServerTranslating
    private let settings: any SettingsStoring
    private let cache: TranslationCache

    init(server: any ServerTranslating, settings: any SettingsStoring, cache: TranslationCache) {
        self.server = server
        self.settings = settings
        self.cache = cache
    }

    func refined(_ texts: [String], pair: LanguagePair, context: [String]) async -> [String: String] {
        let current = settings.load()
        guard current.server.isEnabled else { return [:] }
        let lines = texts.filter { $0.count <= SubGGClient.maximumLength && TextNormalizer.isTranslatable($0) }
        var result: [String: String] = [:]
        for start in stride(from: 0, to: lines.count, by: SubGGClient.maximumLines) {
            let part = Array(lines[start..<min(start + SubGGClient.maximumLines, lines.count)])
            guard let answer = try? await server.translate(part, pair: pair, style: current.server.style, context: context)
            else { break }
            result.merge(answer) { _, new in new }
        }
        // Next time the same line shows the better translation at once.
        if !result.isEmpty { await cache.store(result, pair: pair) }
        return result
    }
}
