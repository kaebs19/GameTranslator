import UIKit

/// Everything the result screen needs.
struct TranslationResult: Identifiable {
    struct Row: Identifiable {
        let id: UUID
        let original: String
        let translation: String?
    }

    let id = UUID()
    let image: UIImage
    let rows: [Row]
    let pair: LanguagePair

    /// `nil` when nothing could be translated.
    var shared: SharedTranslation? {
        let lines = rows.compactMap { row in
            row.translation.map { SharedTranslation.Line(original: row.original, translation: $0) }
        }
        return lines.isEmpty ? nil : SharedTranslation(lines: lines, pair: pair)
    }

    var translatedText: String { rows.compactMap(\.translation).joined(separator: "\n") }
}
