import CoreMedia
import Foundation
import ImageIO
import os

/// Turns captured frames into new lines, off the main actor.
/// `@unchecked`: state is behind a lock and the processor is only used on `queue`.
nonisolated final class ScreenFrameWorker: @unchecked Sendable {
    private struct State {
        var gate = FrameGate(interval: 1)
        var isPaused = false
        var needsReset = false
        var didLogFormat = false
    }

    private static let frameDimension = 1600
    private let state = OSAllocatedUnfairLock(initialState: State())
    private let queue = DispatchQueue(label: "capture.ocr", qos: .utility)
    private let logger = Logger(subsystem: "GameTranslator", category: "capture")
    private let processor: LiveFrameProcessor
    private let language: @Sendable () -> AppLanguage
    private let onLines: @Sendable ([String]) -> Void

    init(
        recognize: @escaping LiveFrameProcessor.Recognize,
        language: @escaping @Sendable () -> AppLanguage,
        onLines: @escaping @Sendable ([String]) -> Void
    ) {
        processor = LiveFrameProcessor(recognize: recognize)
        self.language = language
        self.onLines = onLines
    }

    /// Fast recognition where it can read the language, accurate for the rest.
    static func systemRecognize(
        _ image: CGImage, _ orientation: CGImagePropertyOrientation, _ language: AppLanguage
    ) throws -> [RecognizedLine] {
        let fast = OCRService(mode: .fast)
        let recognizer = fast.readableLanguages.contains(language) ? fast : OCRService(mode: .accurate)
        return try recognizer.recognize(image, orientation: orientation, language: language)
    }

    func setPaused(_ isPaused: Bool) { state.withLock { $0.isPaused = isPaused } }

    func reset() { state.withLock { $0.needsReset = true } }

    func handle(_ pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) {
        let now = ProcessInfo.processInfo.systemUptime
        guard state.withLock({ !$0.isPaused && $0.gate.begin(at: now) }) else { return }
        logFormatOnce(pixelBuffer, orientation)
        guard let frame = LumaImage.downscaled(from: pixelBuffer, maxDimension: Self.frameDimension) else {
            state.withLock { $0.gate.end() }
            return
        }
        queue.async { [self] in
            autoreleasepool { process(frame, orientation: orientation) }
            state.withLock { $0.gate.end() }
        }
    }

    private func process(_ frame: LumaImage, orientation: CGImagePropertyOrientation) {
        let needsReset = state.withLock { state in
            defer { state.needsReset = false }
            return state.needsReset
        }
        if needsReset { processor.reset() }
        let started = ProcessInfo.processInfo.systemUptime
        do {
            let outcome = try processor.process(frame, orientation: orientation, language: language())
            let elapsed = ProcessInfo.processInfo.systemUptime - started
            let memory = MemoryUsage.footprintMegabytes() ?? 0
            logger.info("Frame \(elapsed, format: .fixed(precision: 2), privacy: .public)s, memory \(memory, format: .fixed(precision: 0), privacy: .public) MB")
            if case .newLines(let lines) = outcome { onLines(lines) }
        } catch {
            logger.error("Frame failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Apple does not document the format, so record what the device really sends.
    private func logFormatOnce(_ buffer: CVPixelBuffer, _ orientation: CGImagePropertyOrientation) {
        let isFirst = state.withLock { state in
            defer { state.didLogFormat = true }
            return !state.didLogFormat
        }
        guard isFirst else { return }
        let code = CVPixelBufferGetPixelFormatType(buffer)
        let name = String(decoding: [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: code >> $0) }, as: UTF8.self)
        logger.info("First frame \(CVPixelBufferGetWidth(buffer), privacy: .public)x\(CVPixelBufferGetHeight(buffer), privacy: .public) \(name, privacy: .public) orientation \(orientation.rawValue, privacy: .public)")
    }
}
