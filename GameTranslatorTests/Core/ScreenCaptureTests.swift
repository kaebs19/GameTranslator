import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
import os
import Testing
@testable import GameTranslator

struct PixelBufferTests {
    static let formats = [
        kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
        kCVPixelFormatType_32BGRA, kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
    ]

    @Test(arguments: formats)
    func textIsReadableInEveryCaptureFormat(format: OSType) throws {
        let source = try TestImage.luma(lines: ["Follow the car", "Lose the police"])
        let buffer = try TestPixelBuffer.make(source, format: format)
        let frame = try #require(LumaImage.downscaled(from: buffer, maxDimension: 800))
        #expect(max(frame.width, frame.height) == 800)
        let image = try #require(frame.makeCGImage())
        let lines = try OCRService(mode: .fast).recognize(image, orientation: .up, language: .english)
        #expect(lines.map(\.text) == ["Follow the car", "Lose the police"])
    }

    @Test func unknownFormatIsRejected() throws {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, 8, 8, kCVPixelFormatType_32ARGB, nil, &buffer)
        #expect(LumaImage.downscaled(from: try #require(buffer), maxDimension: 8) == nil)
    }
}

struct ScreenFrameWorkerTests {
    private final class Sink: Sendable {
        let lines = OSAllocatedUnfairLock<[String]>(initialState: [])
    }

    /// Keeps sending the same frame, as a still screen does, until enough lines arrived.
    private func send(_ text: String, to worker: ScreenFrameWorker, until count: Int, in sink: Sink) async throws -> Bool {
        let buffer = try TestPixelBuffer.make(TestImage.luma(lines: [text]), format: kCVPixelFormatType_32BGRA)
        for _ in 0..<200 {
            worker.handle(buffer, orientation: .up)
            if sink.lines.withLock({ $0.count }) >= count { return true }
            try await Task.sleep(for: .milliseconds(50))
        }
        return false
    }

    @Test func publishesOncePausesAndForgetsOnReset() async throws {
        let sink = Sink()
        let worker = ScreenFrameWorker(recognize: ScreenFrameWorker.systemRecognize) {
            .english
        } onLines: { lines in
            sink.lines.withLock { $0 += lines }
        }
        #expect(try await send("Follow the car", to: worker, until: 1, in: sink))
        let same = try TestPixelBuffer.make(
            TestImage.luma(lines: ["Follow the car"]), format: kCVPixelFormatType_32BGRA
        )
        for _ in 0..<15 {
            worker.handle(same, orientation: .up)
            try await Task.sleep(for: .milliseconds(100))
        }
        worker.setPaused(true)
        let paused = try TestPixelBuffer.make(
            TestImage.luma(lines: ["Lose the police"]), format: kCVPixelFormatType_32BGRA
        )
        for _ in 0..<15 {
            worker.handle(paused, orientation: .up)
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(sink.lines.withLock { $0 } == ["Follow the car"])
        worker.setPaused(false)
        worker.reset()
        #expect(try await send("Follow the car", to: worker, until: 2, in: sink))
        #expect(sink.lines.withLock { $0 } == ["Follow the car", "Follow the car"])
    }
}

enum TestPixelBuffer {
    static func make(_ image: LumaImage, format: OSType) throws -> CVPixelBuffer {
        var created: CVPixelBuffer?
        CVPixelBufferCreate(nil, image.width, image.height, format, nil, &created)
        let buffer = try #require(created)
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let isPlanar = CVPixelBufferIsPlanar(buffer)
        let base = try #require(
            isPlanar ? CVPixelBufferGetBaseAddressOfPlane(buffer, 0) : CVPixelBufferGetBaseAddress(buffer)
        )
        let rowBytes = isPlanar ? CVPixelBufferGetBytesPerRowOfPlane(buffer, 0) : CVPixelBufferGetBytesPerRow(buffer)
        for y in 0..<image.height {
            let row = base + y * rowBytes
            for x in 0..<image.width {
                let value = image.pixels[y * image.width + x]
                switch format {
                case kCVPixelFormatType_32BGRA:
                    row.storeBytes(of: UInt32(value) * 0x010101 | 0xFF00_0000, toByteOffset: x * 4, as: UInt32.self)
                case kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange:
                    row.storeBytes(of: UInt16(value) << 8, toByteOffset: x * 2, as: UInt16.self)
                default:
                    row.storeBytes(of: value, toByteOffset: x, as: UInt8.self)
                }
            }
        }
        return buffer
    }
}
