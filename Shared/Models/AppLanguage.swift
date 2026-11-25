import Foundation

/// A language the user can read from or translate to.
nonisolated struct AppLanguage: Hashable, Identifiable, Sendable {
    /// Canonical code without a region: `en`, `ar`, `zh-Hans`.
    let code: String

    var id: String { code }

    /// Collapses regional variants, so `en-US` and `en-GB` are both English.
    init(code: String) {
        let language = Locale.Language(identifier: code)
        let base = language.languageCode?.identifier ?? code
        // Only Chinese is told apart by its script.
        if ["zh", "yue"].contains(base), let script = language.script?.identifier {
            self.code = "\(base)-\(script)"
        } else {
            self.code = base
        }
    }

    func displayName(in locale: Locale) -> String {
        locale.localizedString(forIdentifier: code) ?? code
    }

    /// The name as its own speakers write it.
    var nativeName: String {
        displayName(in: Locale(identifier: code))
    }

    func matches(_ query: String, in locale: Locale) -> Bool {
        [displayName(in: locale), nativeName, code].contains { $0.localizedStandardContains(query) }
    }
}

nonisolated extension AppLanguage {
    static let english = AppLanguage(code: "en")
    static let arabic = AppLanguage(code: "ar")

    /// The list a new user starts with.
    static let defaults: [AppLanguage] = [
        "en", "ar", "fr", "de", "es", "it", "pt", "ru", "ja", "ko", "zh-Hans", "tr"
    ].map(AppLanguage.init(code:))
}
