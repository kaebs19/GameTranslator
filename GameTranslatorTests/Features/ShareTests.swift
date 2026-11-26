import Foundation
import Testing
import UIKit
@testable import GameTranslator

@MainActor
struct ShareTests {
    private func shared(_ count: Int, target: String = "ar", includesOriginal: Bool = true) -> SharedTranslation {
        SharedTranslation(
            lines: (0..<count).map { .init(original: "Follow car \($0)", translation: "سطر \($0)") },
            pair: LanguagePair(source: "en", target: target), includesOriginal: includesOriginal
        )
    }

    @Test func textPutsTheTranslationFirst() {
        #expect(shared(2).text == "سطر 0\nFollow car 0\n\nسطر 1\nFollow car 1")
        #expect(shared(2, includesOriginal: false).text == "سطر 0\n\nسطر 1")
        #expect(shared(2).title == "سطر 0")
    }

    @Test func pictureIsReadableAndGrowsWithTheText() throws {
        let one = try #require(UIImage(data: try ShareCardRenderer.png(of: shared(1)))?.cgImage)
        let three = try #require(UIImage(data: try ShareCardRenderer.png(of: shared(3)))?.cgImage)
        #expect(one.width == Int(ShareCard.width) * 3 && three.width == one.width)
        #expect(three.height > one.height)
        let lines = try OCRService(mode: .accurate).recognize(one, orientation: .up, language: .english)
        #expect(lines.contains { $0.text.contains("Follow") })
    }

    @Test func veryLongTextStillMakesAPicture() throws {
        let limit = try #require(UIImage(data: try ShareCardRenderer.png(of: shared(ShareCard.maximumLines))))
        let more = try #require(UIImage(data: try ShareCardRenderer.png(of: shared(80))))
        #expect(limit.size == more.size)
    }

    @Test func originalCanBeLeftOut() throws {
        let image = try #require(UIImage(data: try ShareCardRenderer.png(of: shared(1, includesOriginal: false)))?.cgImage)
        let lines = try OCRService(mode: .accurate).recognize(image, orientation: .up, language: .english)
        #expect(!lines.contains { $0.text.contains("Follow") })
    }
}
