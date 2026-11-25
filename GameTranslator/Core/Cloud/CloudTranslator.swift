import Foundation

/// A cloud service. Swap the implementation to use another provider.
nonisolated protocol CloudTranslating: Sendable {
    func translate(_ texts: [String], pair: LanguagePair, key: String) async throws -> [String: String]
}

/// Google Cloud Translation (Basic, v2) with the user's own API key.
nonisolated struct GoogleCloudTranslator: CloudTranslating {
    /// Google rejects requests with more segments than this.
    static let maximumSegments = 128
    private static let endpoint = URL(string: "https://translation.googleapis.com/language/translate/v2")!
    private let session: URLSession

    /// Ephemeral: no cookies and nothing written to disk.
    init(session: URLSession = URLSession(configuration: .ephemeral)) {
        self.session = session
    }

    func translate(_ texts: [String], pair: LanguagePair, key: String) async throws -> [String: String] {
        var result: [String: String] = [:]
        for start in stride(from: 0, to: texts.count, by: Self.maximumSegments) {
            let part = Array(texts[start..<min(start + Self.maximumSegments, texts.count)])
            let translated = try await send(part, pair: pair, key: key)
            for (text, translation) in zip(part, translated) { result[text] = translation }
        }
        return result
    }

    private func send(_ texts: [String], pair: LanguagePair, key: String) async throws -> [String] {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: makeRequest(texts, pair: pair, key: key))
        } catch let error as URLError where error.code != .cancelled {
            throw AppError.cloudUnreachable
        }
        try check(response)
        guard let reply = try? JSONDecoder().decode(Reply.self, from: data),
              reply.data.translations.count == texts.count else { throw AppError.cloudUnreachable }
        return reply.data.translations.map(\.translatedText)
    }

    private func makeRequest(_ texts: [String], pair: LanguagePair, key: String) throws -> URLRequest {
        var request = URLRequest(url: Self.endpoint, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // In a header, not the URL, so the key never ends up in logs.
        request.setValue(key, forHTTPHeaderField: "X-goog-api-key")
        if let bundleID = Bundle.main.bundleIdentifier {
            // Lets the user restrict their key to this app.
            request.setValue(bundleID, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        }
        request.httpBody = try JSONEncoder().encode(Body(
            q: texts, source: Self.googleCode(pair.source), target: Self.googleCode(pair.target), format: "text"
        ))
        return request
    }

    private func check(_ response: URLResponse) throws {
        switch (response as? HTTPURLResponse)?.statusCode {
        case 200: return
        case 400, 401, 403: throw AppError.cloudKeyRejected
        case 429: throw AppError.cloudLimitReached
        default: throw AppError.cloudUnreachable
        }
    }

    static func googleCode(_ code: String) -> String {
        switch code {
        case "zh-Hans": "zh-CN"
        case "zh-Hant": "zh-TW"
        case "nb": "no"
        default: code
        }
    }

    private struct Body: Encodable {
        let q: [String]
        let source: String
        let target: String
        let format: String
    }

    private struct Reply: Decodable {
        struct Data: Decodable { let translations: [Translation] }
        struct Translation: Decodable { let translatedText: String }
        let data: Data
    }
}
