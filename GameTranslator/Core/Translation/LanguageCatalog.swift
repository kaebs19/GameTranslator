import Translation

nonisolated protocol LanguageCatalogProviding: Sendable {
    /// Languages the device can translate.
    func translatableLanguages() async -> [AppLanguage]
}

/// Asks the system instead of hard-coding a list, so new iOS languages show up by themselves.
nonisolated struct SystemLanguageCatalog: LanguageCatalogProviding {
    @concurrent
    func translatableLanguages() async -> [AppLanguage] {
        let supported = await LanguageAvailability().supportedLanguages
        return Array(Set(supported.map { AppLanguage(code: $0.maximalIdentifier) }))
    }
}
