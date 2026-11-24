import Foundation

nonisolated enum SourceLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en", french = "fr", german = "de", spanish = "es", italian = "it"
    case portuguese = "pt", russian = "ru", japanese = "ja", korean = "ko", chinese = "zh-Hans"

    var id: String { rawValue }

    /// Code expected by Vision's `recognitionLanguages`.
    var visionCode: String {
        switch self {
        case .english: "en-US"
        case .french: "fr-FR"
        case .german: "de-DE"
        case .spanish: "es-ES"
        case .italian: "it-IT"
        case .portuguese: "pt-BR"
        case .russian: "ru-RU"
        case .japanese: "ja-JP"
        case .korean: "ko-KR"
        case .chinese: "zh-Hans"
        }
    }
}

nonisolated enum TargetLanguage: String, CaseIterable, Identifiable, Sendable {
    case arabic = "ar", english = "en", french = "fr", german = "de", spanish = "es", turkish = "tr"

    var id: String { rawValue }
}

nonisolated extension Locale {
    func displayName(forLanguage code: String) -> String {
        localizedString(forIdentifier: code) ?? code
    }
}

nonisolated enum SettingsKey {
    static let source = "sourceLanguage"
    static let target = "targetLanguage"
}

/// Current settings, stored in the App Group so the extension can read them later.
nonisolated struct AppSettings: Equatable, Sendable {
    var source: SourceLanguage
    var target: TargetLanguage

    static var current: AppSettings {
        let defaults = AppGroup.defaults
        return AppSettings(
            source: defaults.string(forKey: SettingsKey.source).flatMap(SourceLanguage.init) ?? .english,
            target: defaults.string(forKey: SettingsKey.target).flatMap(TargetLanguage.init) ?? .arabic
        )
    }

    var pair: LanguagePair { LanguagePair(source: source.rawValue, target: target.rawValue) }
}
