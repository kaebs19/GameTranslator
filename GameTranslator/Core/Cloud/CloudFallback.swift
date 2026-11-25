import Foundation

/// Used only when on-device translation fails and the user turned the cloud on.
struct CloudFallback {
    private let translator: any CloudTranslating
    private let keys: any KeyStoring
    private let settings: any SettingsStoring

    init(translator: any CloudTranslating, keys: any KeyStoring, settings: any SettingsStoring) {
        self.translator = translator
        self.keys = keys
        self.settings = settings
    }

    /// `nil` when the cloud is off, in which case nothing was sent.
    func translate(_ texts: [String], pair: LanguagePair) async throws -> [String: String]? {
        guard settings.load().usesCloudTranslation, let key = keys.load() else { return nil }
        return try await translator.translate(texts, pair: pair, key: key)
    }
}
