import Foundation

/// Translations the user chose to share.
nonisolated struct SharedTranslation: Equatable, Sendable {
    struct Line: Equatable, Sendable {
        let original: String
        let translation: String
    }

    let lines: [Line]
    let pair: LanguagePair
    var includesOriginal = true

    /// Translation first, its original underneath, a blank line between entries.
    var text: String {
        lines
            .map { includesOriginal ? "\($0.translation)\n\($0.original)" : $0.translation }
            .joined(separator: "\n\n")
    }

    /// Short line for the share sheet.
    var title: String { lines.first?.translation ?? "" }
}
