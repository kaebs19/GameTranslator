import CoreGraphics
import Testing
import UIKit
@testable import GameTranslator

struct OCRServiceTests {
    @Test func flipsVisionBoxToTopLeft() {
        let box = OCRService.topLeftBox(fromVision: CGRect(x: 0.1, y: 0.75, width: 0.5, height: 0.125))
        #expect(box == CGRect(x: 0.1, y: 0.125, width: 0.5, height: 0.125))
    }

    @Test func sortsRowsThenColumns() {
        func line(_ text: String, x: Double, y: Double) -> RecognizedLine {
            RecognizedLine(text: text, boundingBox: CGRect(x: x, y: y, width: 0.2, height: 0.05))
        }
        let sorted = OCRService.sortedInReadingOrder([
            line("bottom", x: 0.1, y: 0.8), line("right", x: 0.6, y: 0.1), line("left", x: 0.1, y: 0.11)
        ])
        #expect(sorted.map(\.text) == ["left", "right", "bottom"])
    }

    @Test func readsTextAndPlacesItsBox() async throws {
        let image = try #require(TestImage.make(lines: ["FOLLOW THE CAR", "Press the button"]))
        let lines = try await OCRService(mode: .accurate).recognizeText(in: image)
        #expect(lines.map { $0.text.lowercased() } == ["follow the car", "press the button"])
        let first = try #require(lines.first)
        #expect(first.boundingBox.midY < 0.5)
    }
}

enum TestImage {
    static func make(lines: [String], size: CGSize = CGSize(width: 1000, height: 500)) -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(red: 0.1, green: 0.15, blue: 0.3, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            for (index, line) in lines.enumerated() {
                (line as NSString).draw(
                    at: CGPoint(x: 100, y: 100 + 200 * index),
                    withAttributes: [.font: UIFont.boldSystemFont(ofSize: 64), .foregroundColor: UIColor.white]
                )
            }
        }.cgImage
    }
}
