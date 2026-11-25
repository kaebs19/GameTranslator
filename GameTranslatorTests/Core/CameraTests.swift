import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
import os
import Testing
@testable import GameTranslator

struct CameraFrameReaderTests {
    private final class Sink: Sendable {
        let texts = OSAllocatedUnfairLock<[[String]]>(initialState: [])
    }

    private func read(
        _ image: LumaImage, region: CameraRegion
    ) async throws -> [String] {
        let sink = Sink()
        let reader = CameraFrameReader { try OCRService(mode: .accurate).recognize($0, orientation: $1, language: $2) }
        reader.setRegion(region)
        reader.setReading(true)
        reader.begin(language: .english) { event in
            guard case .reading(let reading) = event else { return }
            sink.texts.withLock { $0.append(reading.lines.map(\.text)) }
        }
        reader.handle(try TestPixelBuffer.make(image, format: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange))
        for _ in 0..<400 {
            if let result = sink.texts.withLock({ $0.first }) { return result }
            try await Task.sleep(for: .milliseconds(25))
        }
        return []
    }

    @Test func readsOnlyInsideTheBox() async throws {
        let image = try TestImage.luma(lines: ["Follow the car", "Lose the police"])
        let lower = CameraRegion(rect: CGRect(x: 0, y: 0.5, width: 1, height: 0.5), rotationAngle: 0)
        #expect(try await read(image, region: lower) == ["Lose the police"])
    }

    /// Held upright, the phone's sensor delivers a picture lying on its side.
    @Test func readsUprightPhone() async throws {
        let sideways = try TestImage.luma(lines: ["Follow the car", "Lose the police"]).rotatedCounterclockwise()
        let full = CameraRegion(rect: CGRect(x: 0, y: 0, width: 1, height: 1), rotationAngle: 90)
        #expect(try await read(sideways, region: full) == ["Follow the car", "Lose the police"])
        // The picture's top half lies at the left of the sensor.
        let top = CameraRegion(rect: CGRect(x: 0, y: 0, width: 0.5, height: 1), rotationAngle: 90)
        #expect(try await read(sideways, region: top) == ["Follow the car"])
    }

    @Test(arguments: [true, false])
    func nothingIsReadWhenPausedOrEnded(paused: Bool) async throws {
        let sink = Sink()
        let reader = CameraFrameReader { _, _, _ in [RecognizedLine(text: "x", boundingBox: .zero)] }
        reader.begin(language: .english) { event in
            guard case .reading(let reading) = event else { return }
            sink.texts.withLock { $0.append(reading.lines.map(\.text)) }
        }
        reader.setReading(!paused)
        if !paused { reader.end() }
        reader.handle(try TestPixelBuffer.make(
            TestImage.luma(lines: ["A"]), format: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ))
        try await Task.sleep(for: .milliseconds(200))
        #expect(sink.texts.withLock { $0.isEmpty })
    }

    private final class Events: Sendable {
        let stills = OSAllocatedUnfairLock<[CGSize]>(initialState: [])
        let readings = OSAllocatedUnfairLock<[CameraReading]>(initialState: [])
    }

    private func wait(_ condition: () -> Bool) async throws -> Bool {
        for _ in 0..<400 {
            if condition() { return true }
            try await Task.sleep(for: .milliseconds(25))
        }
        return false
    }

    @Test func frozenPictureIsReadAgainWhenTheBoxMoves() async throws {
        let events = Events()
        let reader = CameraFrameReader { try OCRService(mode: .accurate).recognize($0, orientation: $1, language: $2) }
        func region(_ y: Double) -> CameraRegion {
            CameraRegion(rect: CGRect(x: 0, y: y, width: 1, height: 0.5), rotationAngle: 0)
        }
        reader.setRegion(region(0))
        reader.begin(language: .english) { event in
            switch event {
            case .still(let image): events.stills.withLock { $0.append(CGSize(width: image.width, height: image.height)) }
            case .reading(let reading): events.readings.withLock { $0.append(reading) }
            }
        }
        reader.setFrozen(true)
        let format = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        reader.handle(try TestPixelBuffer.make(TestImage.luma(lines: ["Follow the car", "Lose the police"]), format: format))
        #expect(try await wait { events.readings.withLock { !$0.isEmpty } })
        #expect(events.stills.withLock { $0 } == [CGSize(width: 1000, height: 500)])
        // Later frames do not matter any more.
        reader.setReading(true)
        reader.handle(try TestPixelBuffer.make(TestImage.luma(lines: ["Something else"]), format: format))
        for y in [0.2, 0.3, 0.5] { reader.setRegion(region(y)) }
        #expect(try await wait { events.readings.withLock { $0.count } == 2 })
        try await Task.sleep(for: .milliseconds(400))
        let texts = events.readings.withLock { $0.map { $0.lines.map(\.text) } }
        #expect(texts == [["Follow the car"], ["Lose the police"]])
        #expect(events.readings.withLock { $0.allSatisfy(\.isStill) })
    }

    @Test func stillIsUprightAndLiveReadingResumes() async throws {
        let events = Events()
        let reader = CameraFrameReader { _, _, _ in [RecognizedLine(text: "x", boundingBox: .zero)] }
        reader.setRegion(CameraRegion(rect: CGRect(x: 0, y: 0, width: 0.5, height: 1), rotationAngle: 90))
        reader.begin(language: .english) { event in
            switch event {
            case .still(let image): events.stills.withLock { $0.append(CGSize(width: image.width, height: image.height)) }
            case .reading(let reading): events.readings.withLock { $0.append(reading) }
            }
        }
        let buffer = try TestPixelBuffer.make(
            TestImage.luma(lines: ["A"]), format: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        )
        reader.setFrozen(true)
        reader.handle(buffer)
        #expect(try await wait { events.readings.withLock { $0.count } == 1 })
        #expect(events.stills.withLock { $0 } == [CGSize(width: 500, height: 1000)])
        // Upright, the sensor's width is the height of the box.
        #expect(events.readings.withLock { $0.first?.pixelHeight } == 500)
        reader.setFrozen(false)
        reader.setReading(true)
        reader.handle(buffer)
        #expect(try await wait { events.readings.withLock { $0.last?.isStill } == false })
    }

    @Test(arguments: [(0, CGImagePropertyOrientation.up), (90, .right), (180, .down), (270, .left), (360, .up)])
    func anglesBecomeOrientations(angle: Int, expected: CGImagePropertyOrientation) {
        #expect(CameraFrameReader.orientation(forAngle: CGFloat(angle)) == expected)
    }

    @Test func regionOutsideTheFrameIsIgnored() throws {
        let buffer = try TestPixelBuffer.make(
            TestImage.luma(lines: ["A"]), format: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        )
        #expect(LumaImage.downscaled(from: buffer, region: CGRect(x: 2, y: 2, width: 1, height: 1), maxDimension: 100) == nil)
        let partly = LumaImage.downscaled(from: buffer, region: CGRect(x: 0.5, y: -0.5, width: 2, height: 1), maxDimension: 2000)
        #expect(partly?.width == 500 && partly?.height == 250)
    }
}
