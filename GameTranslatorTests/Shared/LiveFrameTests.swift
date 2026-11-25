import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import GameTranslator

struct FrameGateTests {
    @Test func letsOneFramePerIntervalThrough() {
        var gate = FrameGate(interval: 1)
        var accepted = 0
        for frame in 0..<180 where gate.begin(at: Double(frame) / 60) {
            accepted += 1
            gate.end()
        }
        #expect(accepted == 3)
    }

    @Test func blocksWhileBusy() {
        var gate = FrameGate(interval: 1)
        let first = gate.begin(at: 0)
        let whileBusy = gate.begin(at: 5)
        gate.end()
        let afterwards = gate.begin(at: 5)
        #expect(first && !whileBusy && afterwards)
    }
}

struct LumaImageTests {
    @Test func limitsLongestSideAndKeepsAspect() throws {
        let image = try #require(Self.scale(width: 1290, height: 2796, bytesPerRow: 1344, max: 1600))
        #expect(image.height == 1600)
        #expect(image.width == 738)
        #expect(image.pixels.count == 1600 * 738)
    }

    @Test func neverUpscales() throws {
        let image = try #require(Self.scale(width: 100, height: 50, bytesPerRow: 100, max: 1600))
        #expect(image.width == 100 && image.height == 50)
    }

    @Test func rowPaddingDoesNotLeakIntoTheImage() throws {
        var source = [UInt8](repeating: 255, count: 64 * 10)
        for row in 0..<10 { for column in 0..<40 { source[row * 64 + column] = 10 } }
        let image = try #require(source.withUnsafeBytes {
            LumaImage.downscaled(from: $0.baseAddress!, width: 40, height: 10, bytesPerRow: 64, maxDimension: 20)
        })
        #expect(image.pixels.allSatisfy { $0 == 10 })
    }

    private static func scale(width: Int, height: Int, bytesPerRow: Int, max: Int) -> LumaImage? {
        [UInt8](repeating: 100, count: bytesPerRow * height).withUnsafeBytes {
            LumaImage.downscaled(
                from: $0.baseAddress!, width: width, height: height, bytesPerRow: bytesPerRow, maxDimension: max
            )
        }
    }
}

struct FrameFingerprintTests {
    private func fingerprint(_ lines: [String]) throws -> FrameFingerprint {
        try #require(FrameFingerprint(TestImage.luma(lines: lines)))
    }

    @Test func sameFrameIsSimilar() throws {
        #expect(try fingerprint(["Follow the car"]).isSimilar(to: fingerprint(["Follow the car"])))
    }

    @Test func slightNoiseIsSimilar() throws {
        let image = try TestImage.luma(lines: ["Follow the car"])
        let noisy = LumaImage(width: image.width, height: image.height, pixels: image.pixels.enumerated().map {
            $0.offset.isMultiple(of: 2) ? min($0.element, 252) + 3 : $0.element
        })
        let other = try #require(FrameFingerprint(noisy))
        #expect(try fingerprint(["Follow the car"]).isSimilar(to: other))
    }

    @Test(arguments: [["Follow the van"], ["Follow the car", "Go"], []])
    func changedTextIsNotSimilar(lines: [String]) throws {
        #expect(try !fingerprint(["Follow the car"]).isSimilar(to: fingerprint(lines)))
    }
}

struct LiveFrameProcessorTests {
    private final class Recorder {
        var calls = 0
        var results: [[String]] = []
        var error: (any Error)?
    }

    private func makeProcessor(_ recorder: Recorder) -> LiveFrameProcessor {
        LiveFrameProcessor { _, _, _ in
            recorder.calls += 1
            if let error = recorder.error { throw error }
            return recorder.results.removeFirst().map { RecognizedLine(text: $0, boundingBox: .zero) }
        }
    }

    @Test func skipsOCRWhenTheFrameDidNotChange() throws {
        let recorder = Recorder()
        recorder.results = [["Follow the car"]]
        let processor = makeProcessor(recorder)
        let frame = try TestImage.luma(lines: ["A"])
        #expect(try processor.process(frame, orientation: .up, language: .english) == .newLines(["Follow the car"]))
        #expect(try processor.process(frame, orientation: .up, language: .english) == .unchanged)
        #expect(recorder.calls == 1)
    }

    @Test func publishesOnlyUnseenLines() throws {
        let recorder = Recorder()
        recorder.results = [["Follow the car"], ["Follow the car", "Lose the police"], ["follow the CAR"]]
        let processor = makeProcessor(recorder)
        func run(_ text: String) throws -> LiveFrameProcessor.Outcome {
            try processor.process(TestImage.luma(lines: [text]), orientation: .up, language: .english)
        }
        #expect(try run("AAAA") == .newLines(["Follow the car"]))
        #expect(try run("BBBB") == .newLines(["Lose the police"]))
        #expect(try run("MMMM") == .noNewText)
    }

    @Test func dropsNoise() throws {
        let recorder = Recorder()
        recorder.results = [["12:30", "|", "x", "-- a --", "$1,250", "Level 3"]]
        let outcome = try makeProcessor(recorder).process(
            TestImage.luma(lines: ["A"]), orientation: .up, language: .english
        )
        #expect(outcome == .newLines(["Level 3"]))
    }

    @Test func failedFrameIsTriedAgain() throws {
        let recorder = Recorder()
        recorder.error = CocoaError(.featureUnsupported)
        let processor = makeProcessor(recorder)
        let frame = try TestImage.luma(lines: ["A"])
        #expect(throws: CocoaError.self) { try processor.process(frame, orientation: .up, language: .english) }
        recorder.error = nil
        recorder.results = [["Follow the car"]]
        #expect(try processor.process(frame, orientation: .up, language: .english) == .newLines(["Follow the car"]))
    }

    @Test func resetReportsTextStillOnScreenAgain() throws {
        let recorder = Recorder()
        recorder.results = [["Follow the car"], ["Follow the car"]]
        let processor = makeProcessor(recorder)
        let frame = try TestImage.luma(lines: ["A"])
        _ = try processor.process(frame, orientation: .up, language: .english)
        processor.reset()
        #expect(try processor.process(frame, orientation: .up, language: .english) == .newLines(["Follow the car"]))
    }

    @Test func languageChangeRereadsTheSameFrame() throws {
        let recorder = Recorder()
        recorder.results = [["Hello there"], ["Bonjour madame"]]
        let processor = makeProcessor(recorder)
        let frame = try TestImage.luma(lines: ["A"])
        _ = try processor.process(frame, orientation: .up, language: .english)
        let outcome = try processor.process(frame, orientation: .up, language: AppLanguage(code: "fr"))
        #expect(outcome == .newLines(["Bonjour madame"]))
    }

    @Test func joinsSubtitlesButLeavesLongPassagesByLine() throws {
        func lines(_ texts: [String]) -> [RecognizedLine] {
            texts.enumerated().map { index, text in
                RecognizedLine(text: text, boundingBox: CGRect(
                    x: 0.1, y: 0.1 + 0.07 * Double(index), width: 0.6, height: 0.05
                ))
            }
        }
        let subtitle = LiveFrameProcessor { _, _, _ in lines(["Get back to the", "safehouse before dawn"]) }
        let frame = try TestImage.luma(lines: ["A"])
        #expect(try subtitle.process(frame, orientation: .up, language: .english)
            == .newLines(["Get back to the safehouse before dawn"]))
        let passage = ["It was the first day of", "spring and nobody in the", "village knew that the", "bridge had been closed"]
        let long = LiveFrameProcessor { _, _, _ in lines(passage) }
        #expect(try long.process(frame, orientation: .up, language: .english) == .newLines(passage))
    }

    @Test func readsRealFramesWithFastRecognition() throws {
        let recognizer = OCRService(mode: .fast)
        let processor = LiveFrameProcessor { try recognizer.recognize($0, orientation: $1, language: $2) }
        let frame = try TestImage.luma(lines: ["Follow the car", "Lose the police"])
        #expect(try processor.process(frame, orientation: .up, language: .english)
            == .newLines(["Follow the car", "Lose the police"]))
    }

    @Test func readsLandscapeFramesDeliveredRotated() throws {
        let recognizer = OCRService(mode: .fast)
        let processor = LiveFrameProcessor { try recognizer.recognize($0, orientation: $1, language: $2) }
        let frame = try TestImage.luma(lines: ["Follow the car"]).rotatedCounterclockwise()
        #expect(frame.height > frame.width)
        #expect(try processor.process(frame, orientation: .right, language: .english) == .newLines(["Follow the car"]))
    }
}

extension LumaImage {
    func rotatedCounterclockwise() -> LumaImage {
        var output = [UInt8](repeating: 0, count: pixels.count)
        for y in 0..<height { for x in 0..<width { output[(width - 1 - x) * height + y] = pixels[y * width + x] } }
        return LumaImage(width: height, height: width, pixels: output)
    }
}
