import Foundation

/// The SubGG server: a shared cache in front of a language model.
nonisolated protocol ServerTranslating: Sendable {
    /// Returns only the lines the server could translate.
    func translate(
        _ texts: [String], pair: LanguagePair, style: ServerSettings.Style, context: [String]
    ) async throws -> [String: String]
}

/// Talks to the server with an anonymous device token kept in the Keychain.
nonisolated struct SubGGClient: ServerTranslating {
    /// The server takes at most this many lines, each at most `maximumLength` characters.
    static let maximumLines = 20
    static let maximumLength = 500

    static var defaultURL: URL {
        #if DEBUG
        // The simulator reaches a server running on this Mac.
        URL(string: "http://localhost:8080")!
        #else
        URL(string: "https://api.subgg.app")!
        #endif
    }

    private let baseURL: URL
    private let tokens: any KeyStoring
    private let session: URLSession

    /// Ephemeral: no cookies and nothing written to disk.
    init(
        baseURL: URL = SubGGClient.defaultURL, tokens: any KeyStoring = KeychainKeyStore(account: "subggDevice"),
        session: URLSession = URLSession(configuration: .ephemeral)
    ) {
        self.baseURL = baseURL
        self.tokens = tokens
        self.session = session
    }

    func translate(
        _ texts: [String], pair: LanguagePair, style: ServerSettings.Style, context: [String]
    ) async throws -> [String: String] {
        let body = Request(
            texts: texts, source: pair.source, target: pair.target, style: style.rawValue,
            context: context.suffix(3).map { String($0.prefix(Self.maximumLength)) }
        )
        do {
            return try await send(body, token: try await token())
        } catch ServerError.unknownDevice {
            // The server forgot this device (or its data was reset): register again, once.
            tokens.remove()
            return try await send(body, token: try await token())
        }
    }

    // MARK: Requests

    private enum ServerError: Error {
        case unknownDevice
    }

    private struct Request: Encodable {
        let texts: [String]
        let source: String
        let target: String
        let style: String
        let context: [String]
    }

    private struct Reply: Decodable {
        struct Line: Decodable {
            let text: String
            let translation: String?
        }
        let translations: [Line]
    }

    private func send(_ body: Request, token: String) async throws -> [String: String] {
        var request = URLRequest(url: baseURL.appending(path: "v1/translate"), timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await load(request)
        switch (response as? HTTPURLResponse)?.statusCode {
        case 200: break
        case 401: throw ServerError.unknownDevice
        case 429: throw AppError.cloudLimitReached
        default: throw AppError.cloudUnreachable
        }
        guard let reply = try? JSONDecoder().decode(Reply.self, from: data),
              reply.translations.count == body.texts.count else { throw AppError.cloudUnreachable }
        // Keyed by what the app sent: the server tidies spacing in `text`.
        var result: [String: String] = [:]
        for (text, line) in zip(body.texts, reply.translations) {
            if let translation = line.translation { result[text] = translation }
        }
        return result
    }

    private func token() async throws -> String {
        if let token = tokens.load() { return token }
        var request = URLRequest(url: baseURL.appending(path: "v1/devices"), timeoutInterval: 15)
        request.httpMethod = "POST"
        let (data, response) = try await load(request)
        struct Device: Decodable { let token: String }
        guard (response as? HTTPURLResponse)?.statusCode == 201,
              let device = try? JSONDecoder().decode(Device.self, from: data) else { throw AppError.cloudUnreachable }
        try tokens.save(device.token)
        return device.token
    }

    private func load(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError where error.code != .cancelled {
            throw AppError.cloudUnreachable
        }
    }
}
