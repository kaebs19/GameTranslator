import Translation

/// Translation without a view. Cannot download languages, so they must be installed already.
@available(iOS 26, *)
nonisolated enum HeadlessTranslation {
    @concurrent
    static func translate(_ texts: [String], pair: LanguagePair) async throws -> [String: String] {
        let session = TranslationSession(installedSource: pair.sourceLanguage, target: pair.targetLanguage)
        guard await session.isReady else { throw AppError.translationNeedsApp }
        return try await session.translateAll(texts)
    }
}
