import Foundation
import Testing
@testable import GameTranslator

@MainActor
struct ServerRefinerTests {
    private let server = StubServer()
    private let settings = InMemorySettingsStore()
    private let cache = TranslationCache(fileURL: FileManager.default.temporaryDirectory.appending(path: "refiner-\(UUID().uuidString).json"))
    private let pair = LanguagePair(source: "en", target: "ar")

    private func refiner() -> ServerRefiner { ServerRefiner(server: server, settings: settings, cache: cache) }

    private func turnOn(_ style: ServerSettings.Style = .standard) {
        var current = settings.load()
        current.server = ServerSettings(isEnabled: true, style: style)
        settings.save(current)
    }

    @Test func sendsNothingUntilTurnedOn() async {
        #expect(await refiner().refined(["Follow the car"], pair: pair, context: []).isEmpty)
        #expect(server.requests.isEmpty)
    }

    @Test func remembersBetterTranslations() async {
        turnOn(.gulf)
        let result = await refiner().refined(["Follow the car", "12:30"], pair: pair, context: [])
        #expect(result == ["Follow the car": "server:Follow the car"])
        #expect(server.requests.map(\.texts) == [["Follow the car"]] && server.requests.first?.style == .gulf)
        #expect(await cache.translation(for: "Follow the car", pair: pair) == "server:Follow the car")
    }

    @Test func sendsInBatchesTheServerAccepts() async {
        turnOn()
        let lines = (1...45).map { "Line number \($0)" }
        #expect(await refiner().refined(lines, pair: pair, context: []).count == 45)
        #expect(server.requests.map(\.texts.count) == [20, 20, 5])
    }

    @Test func failureKeepsWhatTheAppHas() async {
        turnOn()
        server.fails = true
        #expect(await refiner().refined(["Follow the car"], pair: pair, context: []).isEmpty)
    }
}

/// Answers requests to the fake server.
final class FakeServerProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, String))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let (status, body) = Self.handler?(request) ?? (500, "")
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

@Suite(.serialized)
struct SubGGClientTests {
    private let tokens = StubKeyStore()
    private let pair = LanguagePair(source: "en", target: "ar")

    private func client() -> SubGGClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FakeServerProtocol.self]
        return SubGGClient(baseURL: URL(string: "https://api.test")!, tokens: tokens, session: URLSession(configuration: configuration))
    }

    @Test func registersOnceThenTranslates() async throws {
        var registrations = 0
        FakeServerProtocol.handler = { request in
            if request.url?.path == "/v1/devices" {
                registrations += 1
                return (201, #"{"token":"device-\#(registrations)"}"#)
            }
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer device-1")
            return (200, #"{"translations":[{"text":"Follow the car","translation":"اتبع السيارة"},{"text":"New","translation":null}]}"#)
        }
        let first = try await client().translate(["Follow  the car", "New"], pair: pair, style: .standard, context: [])
        #expect(first == ["Follow  the car": "اتبع السيارة"])
        _ = try await client().translate(["Follow the car", "New"], pair: pair, style: .standard, context: [])
        #expect(registrations == 1 && tokens.key == "device-1")
    }

    @Test func registersAgainWhenTheServerForgetsTheDevice() async throws {
        tokens.key = "old"
        FakeServerProtocol.handler = { request in
            if request.url?.path == "/v1/devices" { return (201, #"{"token":"new"}"#) }
            let auth = request.value(forHTTPHeaderField: "Authorization")
            return auth == "Bearer new" ? (200, #"{"translations":[{"text":"Go","translation":"اذهب"}]}"#) : (401, "")
        }
        #expect(try await client().translate(["Go"], pair: pair, style: .gulf, context: []) == ["Go": "اذهب"])
        #expect(tokens.key == "new")
    }

    @Test func reportsTheDailyLimit() async {
        tokens.key = "t"
        FakeServerProtocol.handler = { _ in (429, "") }
        await #expect(throws: AppError.cloudLimitReached) {
            try await client().translate(["Go"], pair: pair, style: .standard, context: [])
        }
    }
}
