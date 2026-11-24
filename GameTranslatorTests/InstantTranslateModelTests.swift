import Foundation
import Testing
import UIKit
@testable import GameTranslator

/// Uses a stub translator: the system one needs a device and a SwiftUI host.
@MainActor
@Suite(.serialized)
struct InstantTranslateModelTests {
    private let cache = TranslationCache(
        fileURL: FileManager.default.temporaryDirectory.appending(path: "cache-\(UUID().uuidString).json")
    )

    private func makeModel(supported: Bool = true) -> InstantTranslateModel {
        InstantTranslateModel(cache: cache, isSupported: { _ in supported })
    }

    private func imageData(_ lines: [String]) throws -> Data {
        try #require(TestImage.make(lines: lines).flatMap { UIImage(cgImage: $0).pngData() })
    }

    private func waitUntilSettled(_ model: InstantTranslateModel) async throws {
        for _ in 0..<600 {
            if model.phase != .loading, model.phase != .recognizing { return }
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    @Test func fullyCachedImageNeedsNoTranslator() async throws {
        await cache.store(["FOLLOW THE CAR": "اتبع السيارة"], pair: AppSettings.current.pair)
        let model = makeModel()
        let data = try imageData(["FOLLOW THE CAR"])
        model.translate { data }
        try await waitUntilSettled(model)
        #expect(model.phase == .finished)
        #expect(model.configuration == nil)
        #expect(model.rows.map(\.translation) == ["اتبع السيارة"])
        #expect(model.translatedImage != nil)
    }

    @Test func translatesOnlyMissingLinesAndCachesThem() async throws {
        let pair = AppSettings.current.pair
        await cache.store(["FOLLOW THE CAR": "اتبع السيارة"], pair: pair)
        let model = makeModel()
        let data = try imageData(["FOLLOW THE CAR", "Press the button"])
        model.translate { data }
        try await waitUntilSettled(model)
        try #require(model.phase == .translating)
        var requested: [String] = []
        await model.runPendingJob { texts in
            requested = texts
            return Dictionary(uniqueKeysWithValues: texts.map { ($0, "اضغط الزر") })
        }
        #expect(requested == ["Press the button"])
        #expect(model.phase == .finished)
        #expect(await cache.translation(for: "Press the button", pair: pair) == "اضغط الزر")
    }

    @Test func translatorErrorIsShownAndCanBeRetried() async throws {
        let model = makeModel()
        let data = try imageData(["Press the button"])
        model.translate { data }
        try await waitUntilSettled(model)
        try #require(model.phase == .translating)
        await model.runPendingJob { _ in throw CocoaError(.featureUnsupported) }
        guard case .failed(.translationFailed) = model.phase else {
            Issue.record("expected a translation failure, got \(model.phase)")
            return
        }
        model.retry()
        try await waitUntilSettled(model)
        #expect(model.phase == .translating)
    }

    @Test func resultOfAReplacedImageIsDropped() async throws {
        let model = makeModel()
        let data = try imageData(["Press the button"])
        model.translate { data }
        try await waitUntilSettled(model)
        try #require(model.phase == .translating)
        await model.runPendingJob { _ in
            model.reset()
            return ["Press the button": "اضغط الزر"]
        }
        #expect(model.phase == .idle)
        #expect(model.rows.isEmpty)
    }

    @Test func imageWithoutTextFails() async throws {
        let model = makeModel()
        let data = try imageData([])
        model.translate { data }
        try await waitUntilSettled(model)
        #expect(model.phase == .failed(.noText))
    }

    @Test func unsupportedLanguagesFail() async throws {
        let model = makeModel(supported: false)
        let data = try imageData(["Press the button"])
        model.translate { data }
        try await waitUntilSettled(model)
        #expect(model.phase == .failed(.unsupportedLanguages))
    }

    @Test func brokenImageFails() async throws {
        let model = makeModel()
        model.translate { Data("not an image".utf8) }
        try await waitUntilSettled(model)
        #expect(model.phase == .failed(.unreadableImage))
    }
}
