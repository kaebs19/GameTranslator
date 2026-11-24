import Translation

nonisolated extension TranslationSession {
    /// Translates each text and returns them keyed by the original.
    func translateAll(_ texts: [String]) async throws -> [String: String] {
        // TranslationSession is not Sendable, but `.translationTask` hands it to this
        // single task and nothing else touches it.
        nonisolated(unsafe) let session = self
        let requests = texts.map { Request(sourceText: $0) }
        var result: [String: String] = [:]
        for response in try await session.translations(from: requests) {
            result[response.sourceText] = response.targetText
        }
        return result
    }
}
