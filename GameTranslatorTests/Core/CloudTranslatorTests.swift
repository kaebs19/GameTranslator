import Foundation
import Testing
@testable import GameTranslator

/// Answers requests locally; nothing reaches the network.
private final class FakeServer: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var isOffline = false
    nonisolated(unsafe) static var requests: [URLRequest] = []
    nonisolated(unsafe) static var bodies: [[String: Any]] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard !Self.isOffline else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let body = Self.json(request)
        Self.requests.append(request)
        Self.bodies.append(body)
        let texts = body["q"] as? [String] ?? []
        let reply = ["data": ["translations": texts.map { ["translatedText": "g:\($0)"] }]]
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: (try? JSONSerialization.data(withJSONObject: reply)) ?? Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    private static func json(_ request: URLRequest) -> [String: Any] {
        guard let stream = request.httpBodyStream else { return [:] }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while case let count = stream.read(&buffer, maxLength: buffer.count), count > 0 {
            data.append(contentsOf: buffer[0..<count])
        }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }
}

@Suite(.serialized)
struct CloudTranslatorTests {
    private let pair = LanguagePair(source: "en", target: "zh-Hans")
    private let translator: GoogleCloudTranslator

    init() {
        FakeServer.status = 200
        FakeServer.isOffline = false
        FakeServer.requests = []
        FakeServer.bodies = []
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FakeServer.self]
        translator = GoogleCloudTranslator(session: URLSession(configuration: configuration))
    }

    @Test func sendsTextAndKeepsTheKeyOutOfTheURL() async throws {
        let result = try await translator.translate(["Go", "Stop"], pair: pair, key: "secret")
        #expect(result == ["Go": "g:Go", "Stop": "g:Stop"])
        let request = try #require(FakeServer.requests.first)
        #expect(request.url?.scheme == "https")
        #expect(request.url?.absoluteString.contains("secret") == false)
        #expect(request.value(forHTTPHeaderField: "X-goog-api-key") == "secret")
        #expect(FakeServer.bodies.first?["target"] as? String == "zh-CN")
        #expect(FakeServer.bodies.first?["format"] as? String == "text")
    }

    @Test func splitsLongLists() async throws {
        let texts = (1...300).map { "line \($0)" }
        let result = try await translator.translate(texts, pair: pair, key: "k")
        #expect(result.count == 300)
        #expect(FakeServer.bodies.map { ($0["q"] as? [String])?.count } == [128, 128, 44])
    }

    @Test(arguments: [
        (400, AppError.cloudKeyRejected), (403, .cloudKeyRejected), (429, .cloudLimitReached), (500, .cloudUnreachable)
    ])
    func explainsServerErrors(status: Int, expected: AppError) async {
        FakeServer.status = status
        await #expect(throws: expected) { try await translator.translate(["Go"], pair: pair, key: "k") }
    }

    @Test func explainsBeingOffline() async {
        FakeServer.isOffline = true
        await #expect(throws: AppError.cloudUnreachable) { try await translator.translate(["Go"], pair: pair, key: "k") }
    }
}

struct KeychainKeyStoreTests {
    @Test func savesReplacesAndRemoves() throws {
        let store = KeychainKeyStore(account: "test-\(UUID().uuidString)")
        defer { store.remove() }
        #expect(store.load() == nil)
        try store.save("one")
        try store.save("two")
        #expect(store.load() == "two")
        store.remove()
        #expect(store.load() == nil)
    }
}

struct PrivacyManifestTests {
    @Test func appDeclaresItsRequiredReasonAPIs() throws {
        let url = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let plist = try #require(NSDictionary(contentsOf: url))
        let types = try #require(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let names = Set(types.compactMap { $0["NSPrivacyAccessedAPIType"] as? String })
        #expect(names == ["NSPrivacyAccessedAPICategoryUserDefaults", "NSPrivacyAccessedAPICategorySystemBootTime"])
        #expect(plist["NSPrivacyTracking"] as? Bool == false)
    }
}
