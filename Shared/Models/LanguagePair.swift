import Foundation

nonisolated struct LanguagePair: Codable, Hashable, Sendable {
    let source: String
    let target: String

    var sourceLanguage: Locale.Language { Locale.Language(identifier: source) }
    var targetLanguage: Locale.Language { Locale.Language(identifier: target) }
    var isSameLanguage: Bool { source == target }
    var isTargetRightToLeft: Bool { targetLanguage.characterDirection == .rightToLeft }
}
