import CoreGraphics
import Testing
import UIKit
@testable import GameTranslator

struct ImageTranslationRendererTests {
    @Test func keepsImageSizeAndPaintsOnlyTheBox() async throws {
        let image = try #require(TestImage.make(lines: ["FOLLOW THE CAR"]))
        let box = CGRect(x: 0.1, y: 0.2, width: 0.55, height: 0.16)
        let output = try #require(await ImageTranslationRenderer().render(
            image, overlays: [TextOverlay(text: "اتبع السيارة", boundingBox: box)]
        ))
        #expect(output.width == image.width && output.height == image.height)
        let far = CGRect(x: 900, y: 400, width: 40, height: 40)
        #expect(RegionColor.sample(output, in: far) == RegionColor.sample(image, in: far))
        #expect(pngData(output) != pngData(image))
    }

    @Test func samplesBackgroundNotText() throws {
        let image = try #require(TestImage.make(lines: ["FOLLOW THE CAR"]))
        let color = RegionColor.sample(image, in: CGRect(x: 90, y: 95, width: 560, height: 90))
        #expect(!color.isLight)
        #expect(color.blue > color.red)
    }

    @Test func picksReadableTextColor() {
        #expect(RegionColor.black.readableTextColor == .white)
        #expect(RegionColor(red: 240, green: 240, blue: 200).readableTextColor == .black)
    }

    @Test(arguments: ["اذهب", "اتبع السيارة ولا تدعها تهرب منك في شوارع المدينة"])
    func fittedTextStaysInsideItsBox(text: String) {
        let size = CGSize(width: 420, height: 60)
        let fontSize = ImageTranslationRenderer.fittingFontSize(for: text, in: size)
        #expect(ImageTranslationRenderer.fits(text, fontSize: fontSize, in: size))
    }

    @Test func shortTextInATallBlockKeepsTheOriginalSize() {
        let size = CGSize(width: 900, height: 200)
        let free = ImageTranslationRenderer.fittingFontSize(for: "اذهب", in: size)
        let capped = ImageTranslationRenderer.fittingFontSize(for: "اذهب", in: size, maximum: 60)
        #expect(free > 100)
        #expect(capped <= 60)
    }

    @Test func boxIsClampedToTheImage() {
        let size = CGSize(width: 100, height: 100)
        let rect = ImageTranslationRenderer.pixelRect(for: CGRect(x: 0, y: 0, width: 1, height: 1), in: size)
        #expect(rect == CGRect(origin: .zero, size: size))
    }

    private func pngData(_ image: CGImage) -> Data? { UIImage(cgImage: image).pngData() }
}
