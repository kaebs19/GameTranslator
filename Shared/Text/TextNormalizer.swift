import Foundation

nonisolated enum TextNormalizer {
    /// Trims and squeezes every whitespace run to one space. Keeps case.
    static func collapsingWhitespace(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Key for "have I already seen this line?" comparisons:
    /// case, accents, punctuation and spacing are ignored.
    static func comparisonKey(_ text: String) -> String {
        let folded = text.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        let kept = String(folded.map { $0.isLetter || $0.isNumber ? $0 : " " })
        return collapsingWhitespace(kept)
    }

    /// Scores, timers and lone symbols have nothing to translate.
    static func isTranslatable(_ text: String) -> Bool {
        text.contains(where: \.isLetter)
    }

    /// Stricter check for live frames, where textures are often misread as stray symbols.
    static func looksLikeText(_ text: String) -> Bool {
        let visible = text.filter { !$0.isWhitespace }
        let letters = visible.count(where: \.isLetter)
        return letters >= 2 && letters * 2 >= visible.count
    }
}
