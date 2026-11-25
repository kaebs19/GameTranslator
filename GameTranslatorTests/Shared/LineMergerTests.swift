import CoreGraphics
import Testing
@testable import GameTranslator

struct LineMergerTests {
    /// Lines stacked with normal line spacing, on a 16:9 image.
    private func stack(
        _ texts: [String], x: Double = 0.2, widths: [Double]? = nil, height: Double = 0.05, gap: Double = 0.015
    ) -> [RecognizedLine] {
        texts.enumerated().map { index, text in
            RecognizedLine(text: text, boundingBox: CGRect(
                x: x, y: 0.1 + Double(index) * (height + gap), width: widths?[index] ?? 0.5, height: height
            ))
        }
    }

    private func texts(_ lines: [RecognizedLine], aspect: CGFloat = 16 / 9) -> [String] {
        LineMerger.blocks(from: lines, aspectRatio: aspect).map(\.text)
    }

    @Test func joinsAWrappedSubtitle() {
        #expect(texts(stack(["Get back to the safehouse before", "the police find your car."]))
            == ["Get back to the safehouse before the police find your car."])
    }

    @Test func joinsACenteredSubtitle() {
        let lines = [
            RecognizedLine(text: "I told you already,", boundingBox: CGRect(x: 0.3, y: 0.8, width: 0.4, height: 0.05)),
            RecognizedLine(text: "We leave at dawn", boundingBox: CGRect(x: 0.36, y: 0.865, width: 0.28, height: 0.05))
        ]
        #expect(texts(lines) == ["I told you already, We leave at dawn"])
    }

    @Test func joinsThreeLines() {
        #expect(texts(stack(["This is a long sentence that", "keeps going over several lines", "until it ends."])).count == 1)
    }

    @Test(arguments: [
        ["New Game", "Continue", "Options", "Quit"],
        ["Start a new mission", "Load saved game", "Change the settings"],
        ["RESUME GAME", "SAVE GAME", "EXIT TO MENU"],
        ["Inventory", "weapons", "armor"]
    ])
    func keepsMenuEntriesApart(menu: [String]) {
        #expect(texts(stack(menu)) == menu)
    }

    @Test(arguments: [".", "!", "?", ":", "…"])
    func finishedSentenceIsNotContinued(end: String) {
        let lines = ["Get in the car\(end)", "drive to the port"]
        #expect(texts(stack(lines)) == lines)
    }

    @Test func distantLinesStayApart() {
        let lines = ["Follow the man to", "the old garage"]
        #expect(texts(stack(lines, gap: 0.2)) == lines)
    }

    @Test func differentFontSizesStayApart() {
        let lines = [
            RecognizedLine(text: "The mission of", boundingBox: CGRect(x: 0.2, y: 0.1, width: 0.5, height: 0.1)),
            RecognizedLine(text: "a lifetime", boundingBox: CGRect(x: 0.2, y: 0.21, width: 0.3, height: 0.04))
        ]
        #expect(texts(lines).count == 2)
    }

    @Test func columnsDoNotMix() {
        let left = stack(["Talk to the man in", "the red house"], x: 0.05, widths: [0.3, 0.2])
        let right = stack(["Find the key before", "the door closes"], x: 0.6, widths: [0.3, 0.2])
        let reading = OCRService.sortedInReadingOrder(left + right)
        #expect(Set(texts(reading)) == ["Talk to the man in the red house", "Find the key before the door closes"])
    }

    @Test func capitalsAreJoinedOnlyWhenClearlyUnfinished() {
        #expect(texts(stack(["GET BACK TO THE", "SAFEHOUSE"])) == ["GET BACK TO THE SAFEHOUSE"])
        #expect(texts(stack(["MISSION PASSED", "RESPECT EARNED"])).count == 2)
    }

    @Test func repairsHyphenationAndJapaneseSpacing() {
        #expect(LineMerger.joined(["under-", "ground"]) == "underground")
        #expect(LineMerger.joined(["警察が来る前に", "家に戻れ"]) == "警察が来る前に家に戻れ")
    }

    @Test func blockCoversAllItsLines() throws {
        let lines = stack(["Get back to the", "safehouse now"], widths: [0.5, 0.3])
        let block = try #require(LineMerger.blocks(from: lines, aspectRatio: 16 / 9).first)
        #expect(block.lines.count == 2)
        #expect(block.boundingBox == lines[0].boundingBox.union(lines[1].boundingBox))
        #expect(abs(block.lineHeight - 0.05) < 0.0001)
    }

    @Test func emptyInputIsFine() {
        #expect(texts([]).isEmpty)
    }
}
