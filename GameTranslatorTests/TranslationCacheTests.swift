import Foundation
import Testing
@testable import GameTranslator

struct TranslationCacheTests {
    private let url = FileManager.default.temporaryDirectory.appending(path: "cache-\(UUID().uuidString).json")
    private let pair = LanguagePair(source: "en", target: "ar")

    @Test func returnsStoredTranslationIgnoringSpacing() async {
        let cache = TranslationCache(fileURL: url)
        await cache.store(["Follow the car": "اتبع السيارة"], pair: pair)
        #expect(await cache.translation(for: " Follow  the car ", pair: pair) == "اتبع السيارة")
        #expect(await cache.translation(for: "Lose the police", pair: pair) == nil)
    }

    @Test func separatesLanguagePairs() async {
        let cache = TranslationCache(fileURL: url)
        await cache.store(["Go": "اذهب"], pair: pair)
        #expect(await cache.translation(for: "Go", pair: LanguagePair(source: "en", target: "fr")) == nil)
    }

    @Test func survivesRelaunch() async {
        await TranslationCache(fileURL: url).store(["Go": "اذهب"], pair: pair)
        #expect(await TranslationCache(fileURL: url).translation(for: "Go", pair: pair) == "اذهب")
    }

    @Test func clearRemovesMemoryAndDisk() async {
        let cache = TranslationCache(fileURL: url)
        await cache.store(["Go": "اذهب"], pair: pair)
        await cache.clear()
        #expect(await cache.translation(for: "Go", pair: pair) == nil)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func evictsOldestBeyondCapacity() async {
        let cache = TranslationCache(fileURL: url, capacity: 2)
        for word in ["one", "two", "three"] { await cache.store([word: word], pair: pair) }
        #expect(await cache.translation(for: "one", pair: pair) == nil)
        #expect(await cache.translation(for: "three", pair: pair) == "three")
    }
}
