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

    var translatedText: String { rows.compactMap(\.translation).joined(separator: "\n") }
}
