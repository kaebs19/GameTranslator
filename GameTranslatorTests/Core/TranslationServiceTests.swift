import Foundation
import Testing
@testable import GameTranslator

/// Plays the part of the SwiftUI host: calls `drainQueue` with a fake session.
@MainActor
struct TranslationServiceTests {
    private let pair = LanguagePair(source: "en", target: "ar")
    private let cache = TranslationCache(
        fileURL: FileManager.default.temporaryDirectory.appending(path: "cache-\(UUID().uuidString).json")
    )

    private func makeService(supported: Bool = true) -> TranslationService {
        TranslationService(
            cache: cache, isSupported: { _ in supported }, isHostActive: true, headlessSession: { _ in nil }
        )
    }

    private func fake(_ texts: [String]) -> [String: String] {
        Dictionary(texts.map { ($0, "ar:\($0)") }) { first, _ in first }
    }

    @Test func cachedTextsNeverNeedASession() async throws {
        await cache.store(["Go": "اذهب"], pair: pair)
        let service = makeService()
        #expect(try await service.translations(for: ["Go", "Go"], pair: pair) == ["Go": "اذهب"])
        #expect(service.configuration == nil)
    }

    @Test func sendsOnlyMissingTextsOnceInOrderAndCachesThem() async throws {
        await cache.store(["Go": "اذهب"], pair: pair)
        let service = makeService()
        let request = Task { try await service.translations(for: ["Zoo", "Go", "Car", "Zoo"], pair: pair) }
        #expect(try await eventually { service.configuration != nil })
        var sent: [[String]] = []
        await service.drainQueue { sent.append($0); return fake($0) }
        #expect(try await request.value == ["Go": "اذهب", "Zoo": "ar:Zoo", "Car": "ar:Car"])
        #expect(sent == [["Zoo", "Car"]])
        #expect(await cache.translation(for: "Car", pair: pair) == "ar:Car")
    }

    @Test func secondRequestWithSamePairRestartsTheSession() async throws {
        let service = makeService()
        var version: Int?
        for text in ["One", "Two"] {
            let request = Task { try await service.translations(for: [text], pair: pair) }
            #expect(try await eventually { service.configuration != nil && service.configuration?.version != version })
            version = service.configuration?.version
            await service.drainQueue { fake($0) }
            #expect(try await request.value == [text: "ar:\(text)"])
        }
    }

    @Test func requestsForAnotherPairGetTheirOwnSession() async throws {
        let service = makeService()
        let french = LanguagePair(source: "en", target: "fr")
        let first = Task { try await service.translations(for: ["One"], pair: pair) }
        #expect(try await eventually { service.configuration != nil })
        let arabicConfiguration = service.configuration
        var second: Task<[String: String], any Error>?
        await service.drainQueue { texts in
            second = Task { try await service.translations(for: ["Two"], pair: french) }
            try await Task.sleep(for: .milliseconds(200))
            return fake(texts)
        }
        _ = try await first.value
        #expect(service.configuration != arabicConfiguration)
        #expect(service.configuration?.target == french.targetLanguage)
        await service.drainQueue { fake($0) }
        #expect(try await second?.value == ["Two": "ar:Two"])
    }

    @Test func sessionErrorReachesTheCallerAndIsNotCached() async throws {
        let service = makeService()
        let request = Task { try await service.translations(for: ["Go"], pair: pair) }
        #expect(try await eventually { service.configuration != nil })
        await service.drainQueue { _ in throw AppError.noText }
        await #expect(throws: AppError.noText) { try await request.value }
        #expect(await cache.translation(for: "Go", pair: pair) == nil)
    }

    @Test func cancelledRequestIsNotTranslated() async throws {
        let service = makeService()
        let request = Task { try await service.translations(for: ["Go"], pair: pair) }
        #expect(try await eventually { service.configuration != nil })
        request.cancel()
        await #expect(throws: CancellationError.self) { try await request.value }
        var calls = 0
        await service.drainQueue { calls += 1; return fake($0) }
        #expect(calls == 0)
    }

    @Test func rejectsUnsupportedAndIdenticalLanguages() async {
        await #expect(throws: AppError.unsupportedLanguages) {
            try await makeService(supported: false).translations(for: ["Go"], pair: pair)
        }
        await #expect(throws: AppError.sameLanguage) {
            try await makeService().translations(for: ["Go"], pair: LanguagePair(source: "en", target: "en"))
        }
    }

    // MARK: Background

    private func makeBackgroundService(
        headless: TranslationService.Translate? = nil
    ) -> TranslationService {
        TranslationService(
            cache: cache, isSupported: { _ in true }, isHostActive: false, headlessSession: { _ in headless }
        )
    }

    @Test func backgroundUsesHeadlessSessionAndCaches() async throws {
        let service = makeBackgroundService(headless: { fake($0) })
        #expect(try await service.translations(for: ["Go"], pair: pair) == ["Go": "ar:Go"])
        #expect(service.configuration == nil)
        #expect(await cache.translation(for: "Go", pair: pair) == "ar:Go")
    }

    @Test func backgroundWithoutHeadlessSessionAsksForTheApp() async throws {
        await cache.store(["Go": "اذهب"], pair: pair)
        let service = makeBackgroundService()
        #expect(try await service.translations(for: ["Go"], pair: pair) == ["Go": "اذهب"])
        await #expect(throws: AppError.translationNeedsApp) {
            try await service.translations(for: ["Car"], pair: pair)
        }
    }

    @Test func leavingTheAppDoesNotLeaveWaitingRequestsHanging() async throws {
        for headless in [nil, { fake($0) }] as [TranslationService.Translate?] {
            let service = TranslationService(
                cache: TranslationCache(fileURL: URL.temporaryDirectory.appending(path: UUID().uuidString)),
                isSupported: { _ in true }, isHostActive: true, headlessSession: { _ in headless }
            )
            let request = Task { try await service.translations(for: ["Go"], pair: pair) }
            #expect(try await eventually { service.configuration != nil })
            service.hostDidChange(isActive: false)
            if headless == nil {
                await #expect(throws: AppError.translationNeedsApp) { try await request.value }
            } else {
                #expect(try await request.value == ["Go": "ar:Go"])
            }
        }
    }

    // MARK: Cloud fallback

    private func makeCloudService(
        isOn: Bool, key: String? = "k", supported: Bool = false, cloud: StubCloud
    ) -> TranslationService {
        let settings = InMemorySettingsStore()
        var current = settings.load()
        current.usesCloudTranslation = isOn
        settings.save(current)
        return TranslationService(
            cache: cache, isSupported: { _ in supported }, isHostActive: false,
            headlessSession: { _ in { fake($0) } },
            cloud: CloudFallback(translator: cloud, keys: StubKeyStore(key: key), settings: settings)
        )
    }

    @Test func cloudHelpsOnlyWhenTheDeviceCannot() async throws {
        let cloud = StubCloud()
        let service = makeCloudService(isOn: true, cloud: cloud)
        #expect(try await service.translations(for: ["Go"], pair: pair) == ["Go": "cloud:Go"])
        #expect(await cache.translation(for: "Go", pair: pair) == "cloud:Go")
        #expect(try await service.translations(for: ["Go"], pair: pair) == ["Go": "cloud:Go"])
        #expect(cloud.requests.count == 1)
    }

    @Test func nothingIsSentWhenTheDeviceCanTranslate() async throws {
        let cloud = StubCloud()
        let service = makeCloudService(isOn: true, supported: true, cloud: cloud)
        #expect(try await service.translations(for: ["Go"], pair: pair) == ["Go": "ar:Go"])
        #expect(cloud.requests.isEmpty)
    }

    @Test(arguments: [(false, "k"), (true, nil)] as [(Bool, String?)])
    func nothingIsSentWithoutConsentAndKey(isOn: Bool, key: String?) async {
        let cloud = StubCloud()
        let service = makeCloudService(isOn: isOn, key: key, cloud: cloud)
        await #expect(throws: AppError.unsupportedLanguages) {
            try await service.translations(for: ["Go"], pair: pair)
        }
        #expect(cloud.requests.isEmpty)
    }

    @Test func cloudFailureIsReported() async {
        let cloud = StubCloud()
        cloud.error = .cloudUnreachable
        let service = makeCloudService(isOn: true, cloud: cloud)
        await #expect(throws: AppError.cloudUnreachable) {
            try await service.translations(for: ["Go"], pair: pair)
        }
    }

    // MARK: Preparing languages

    @Test func preparingUsesTheHostWithoutTranslating() async throws {
        let service = makeService()
        let request = Task { try await service.prepare(pair) }
        #expect(try await eventually { service.configuration != nil })
        var prepared = 0
        var translated = 0
        await service.drainQueue { texts in
            translated += 1
            return fake(texts)
        } prepare: {
            prepared += 1
        }
        try await request.value
        #expect(prepared == 1 && translated == 0)
    }

    @Test func preparingNeedsTheAppOpen() async {
        await #expect(throws: AppError.translationNeedsApp) {
            try await makeBackgroundService(headless: { fake($0) }).prepare(pair)
        }
    }

    @Test func leavingTheAppEndsWaitingPreparation() async throws {
        let service = TranslationService(
            cache: cache, isSupported: { _ in true }, isHostActive: true, headlessSession: { _ in { fake($0) } }
        )
        let request = Task { try await service.prepare(pair) }
        #expect(try await eventually { service.configuration != nil })
        service.hostDidChange(isActive: false)
        await #expect(throws: AppError.translationNeedsApp) { try await request.value }
    }
}
