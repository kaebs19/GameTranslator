import Foundation

nonisolated enum SubGGError: Error, Equatable {
    case unreachable
    case dailyLimit
    case unknownDevice
}

/// The SubGG server: a shared cache in front of a language model.
nonisolated protocol ServerTranslating: Sendable {
    /// Returns only the lines the server could translate.
    func translate(
        _ texts: [String], pair: LanguagePair, style: ServerSettings.Style, context: [String]
    ) async throws -> [String: String]
}

/// A TV linked through the server.
nonisolated struct ServerTV: Equatable, Sendable, Identifiable, Decodable {
    let id: String
    let name: String?
    let isConnected: Bool
}

/// How lines look on the TV, sent with every message.
nonisolated struct TVLook: Encodable, Equatable, Sendable {
    var position: String
    var size: String
    var showsOriginal: Bool

    init(_ settings: TVSettings) {
        position = settings.position.rawValue
        size = settings.textSize.rawValue
        showsOriginal = settings.showsOriginal
    }
}

/// Talks to the server with an anonymous device token, kept in the Keychain shared with the broadcast
/// extension: both are the same device to the server.
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

    static var sharedTokens: any KeyStoring {
        KeychainKeyStore(account: "subggDevice", accessGroup: AppGroup.identifier)
    }

    private let baseURL: URL
    private let tokens: any KeyStoring
    private let session: URLSession

    /// Ephemeral: no cookies and nothing written to disk.
    init(
        baseURL: URL = SubGGClient.defaultURL, tokens: any KeyStoring = SubGGClient.sharedTokens,
        session: URLSession = URLSession(configuration: .ephemeral)
    ) {
        self.baseURL = baseURL
        self.tokens = tokens
        self.session = session
    }

    // MARK: Translation

    func translate(
        _ texts: [String], pair: LanguagePair, style: ServerSettings.Style, context: [String]
    ) async throws -> [String: String] {
        let body = TranslateRequest(
            texts: texts, source: pair.source, target: pair.target, style: style.rawValue, context: Self.context(context), look: nil
        )
        let reply: TranslateReply = try await authorized { try await send("v1/translate", body: body, token: $0) }
        return Self.keyed(texts, reply)
    }

    /// Translates what the broadcast read and shows it on the linked TVs in one request.
    /// An empty list clears the TVs.
    func translateForTV(
        _ texts: [String], pair: LanguagePair, style: ServerSettings.Style, context: [String], look: TVLook
    ) async throws -> [String: String] {
        let body = TranslateRequest(
            texts: texts, source: pair.source, target: pair.target, style: style.rawValue, context: Self.context(context), look: look
        )
        let reply: TranslateReply = try await authorized { try await send("v1/tv/translate", body: body, token: $0) }
        return Self.keyed(texts, reply)
    }

    // MARK: TVs

    /// A code to type on the TV app, valid for a few minutes.
    func newTVCode() async throws -> String {
        struct Reply: Decodable { let code: String }
        let reply: Reply = try await authorized { try await send("v1/tv/links", body: Empty(), token: $0, expect: 201) }
        return reply.code
    }

    func tvs() async throws -> [ServerTV] {
        struct Reply: Decodable { let items: [ServerTV] }
        let reply: Reply = try await authorized { try await send("v1/tv/links", body: nil as Empty?, token: $0, method: "GET") }
        return reply.items
    }

    func removeTV(_ id: String) async throws {
        let _: Ignored = try await authorized { try await send("v1/tv/links/\(id)", body: nil as Empty?, token: $0, method: "DELETE") }
    }

    // MARK: Requests

    private struct Empty: Codable {}
    private struct Ignored: Decodable {}

    private struct TranslateRequest: Encodable {
        let texts: [String]
        let source: String
        let target: String
        let style: String
        let context: [String]
        let look: TVLook?
    }

    private struct TranslateReply: Decodable {
        struct Line: Decodable {
            let text: String
            let translation: String?
        }
        let translations: [Line]
    }

    private static func context(_ lines: [String]) -> [String] {
        lines.suffix(3).map { String($0.prefix(maximumLength)) }
    }

    /// Keyed by what the app sent: the server tidies spacing in `text`.
    private static func keyed(_ texts: [String], _ reply: TranslateReply) -> [String: String] {
        var result: [String: String] = [:]
        for (text, line) in zip(texts, reply.translations) {
            if let translation = line.translation { result[text] = translation }
        }
        return result
    }

    /// The server forgot this device (or its data was reset): register again, once.
    private func authorized<T>(_ request: (String) async throws -> T) async throws -> T {
        do {
            return try await request(try await token())
        } catch SubGGError.unknownDevice {
            tokens.remove()
            return try await request(try await token())
        }
    }

    private func send<Body: Encodable, Reply: Decodable>(
        _ path: String, body: Body?, token: String, method: String = "POST", expect: Int = 200
    ) async throws -> Reply {
        var request = URLRequest(url: baseURL.appending(path: path), timeoutInterval: 15)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        let (data, response) = try await load(request)
        switch (response as? HTTPURLResponse)?.statusCode {
        case expect: break
        case 401: throw SubGGError.unknownDevice
        case 429: throw SubGGError.dailyLimit
        default: throw SubGGError.unreachable
        }
        if Reply.self == Ignored.self { return Ignored() as! Reply }
        guard let reply = try? JSONDecoder().decode(Reply.self, from: data) else { throw SubGGError.unreachable }
        return reply
    }

    private func token() async throws -> String {
        if let token = tokens.load() { return token }
        var request = URLRequest(url: baseURL.appending(path: "v1/devices"), timeoutInterval: 15)
        request.httpMethod = "POST"
        let (data, response) = try await load(request)
        struct Device: Decodable { let token: String }
        guard (response as? HTTPURLResponse)?.statusCode == 201,
              let device = try? JSONDecoder().decode(Device.self, from: data) else { throw SubGGError.unreachable }
        try tokens.save(device.token)
        return device.token
    }

    private func load(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError where error.code != .cancelled {
            throw SubGGError.unreachable
        }
    }
}
