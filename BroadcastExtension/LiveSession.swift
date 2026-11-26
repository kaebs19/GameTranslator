import CoreMedia
import Foundation
import ImageIO
import os
import ReplayKit

/// One broadcast: throttles frames, processes them one at a time and publishes new lines.
/// `@unchecked`: the gate is behind a lock; everything else mutable is only used on `queue`.
final class LiveSession: @unchecked Sendable {
    private enum Limits {
        /// iOS kills the extension near 50 MB, so stop feeding OCR before that.
        static let memoryMegabytes = 40.0
        /// Enough for subtitles while one frame stays under 2 MB.
        static let frameDimension = 1600
    }

    private let id = UUID()
    private let channel: LiveChannel
    private let settings = UserDefaultsSettingsStore()
    private let processor: LiveFrameProcessor
    /// Used instead of `processor` while remote play sends to the TV.
    private let relay: TVRelay
    private let queue = DispatchQueue(label: "live.ocr", qos: .utility)
    private let gate = OSAllocatedUnfairLock(initialState: FrameGate(interval: 1))
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BroadcastExtension", category: "live")
    private var heartbeat: (any DispatchSourceTimer)?
    private var generation = 0
    private var notificationThrottle = NotificationThrottle()
    private var sequence = 0
    private var peakMemory = 0.0
    private var skippedForMemory = 0

    init(channel: LiveChannel, recognizer: OCRService) {
        self.channel = channel
        processor = LiveFrameProcessor {
            try recognizer.recognize($0, orientation: $1, language: $2)
        }
        // Subtitles are clean digital text on a small crop, so the careful reader fits in memory.
        let careful = OCRService(mode: .accurate)
        let client = SubGGClient()
        relay = TVRelay(
            recognize: { try careful.recognize($0, orientation: $1, language: $2) },
            send: { texts in
                let current = UserDefaultsSettingsStore().load()
                _ = try? await client.translateForTV(
                    texts, pair: current.pair, style: current.server.style, context: [], look: TVLook(current.tv)
                )
            }
        )
    }

    // MARK: Lifecycle

    func start() {
        queue.async { [self] in
            // Text from an earlier broadcast that the app never read is out of date.
            channel.removeAllBatches()
            resumeControl()
            beat()
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + LiveStatus.heartbeatInterval, repeating: LiveStatus.heartbeatInterval)
            timer.setEventHandler { [weak self] in self?.beat() }
            timer.resume()
            heartbeat = timer
            logger.info("Broadcast started")
        }
    }

    /// Blocks so the final status is on disk before the system ends the process.
    func finish() {
        queue.sync {
            heartbeat?.cancel()
            heartbeat = nil
            writeStatus(isRunning: false)
            logger.info("Broadcast finished. Peak memory \(self.peakMemory, format: .fixed(precision: 1), privacy: .public) MB, frames skipped for memory \(self.skippedForMemory, privacy: .public)")
        }
    }

    /// A pause left over from an earlier broadcast must not silence this one.
    private func resumeControl() {
        var control = channel.control()
        generation = control.generation
        control.isPaused = false
        try? channel.write(control)
    }

    private func beat() {
        logMemory()
        writeStatus(isRunning: true)
    }

    private func writeStatus(isRunning: Bool) {
        do {
            try channel.write(LiveStatus(sessionID: id, isRunning: isRunning, heartbeat: .now))
            DarwinNotification.post(DarwinNotification.liveUpdate)
        } catch {
            logger.error("Status write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Frames

    func handle(_ sampleBuffer: CMSampleBuffer) {
        let now = ProcessInfo.processInfo.systemUptime
        guard gate.withLock({ $0.begin(at: now) }) else { return }
        // Copied small right away so the large system buffer is released immediately.
        guard let frame = Self.downscaledFrame(from: sampleBuffer) else {
            gate.withLock { $0.end() }
            return
        }
        let orientation = Self.orientation(of: sampleBuffer)
        queue.async { [self] in
            autoreleasepool { process(frame, orientation: orientation) }
            gate.withLock { $0.end() }
        }
    }

    private func process(_ frame: LumaImage, orientation: CGImagePropertyOrientation) {
        let control = channel.control()
        if control.generation != generation {
            generation = control.generation
            processor.reset()
        }
        guard !control.isPaused else { return }
        if let used = logMemory(), used > Limits.memoryMegabytes {
            skippedForMemory += 1
            logger.error("Frame skipped: memory above limit")
            return
        }
        do {
            let current = settings.load()
            // Subtitles change quickly; the TV should follow within half a second.
            gate.withLock { $0.interval = current.remotePlay.sendsToTV ? 0.5 : 1 }
            if current.remotePlay.sendsToTV {
                let lines = try relay.process(
                    frame, orientation: orientation, region: current.remotePlay.region, language: current.source
                )
                if !lines.isEmpty { try publish(lines) }
                return
            }
            if case .newLines(let lines) = try processor.process(frame, orientation: orientation, language: current.source) {
                try publish(lines)
                if current.live.sendsNotifications { notify() }
            }
        } catch {
            logger.error("Frame failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func publish(_ lines: [String]) throws {
        sequence += 1
        try channel.send(LiveBatch(sessionID: id, sequence: sequence, date: .now, lines: lines))
        DarwinNotification.post(DarwinNotification.liveUpdate)
        // Counts only: recognized text is never logged.
        logger.info("Published \(lines.count, privacy: .public) lines")
    }

    /// No game text here: the extension cannot translate, and banners may show on the Lock Screen.
    /// iOS hides it while the app itself is open.
    private func notify() {
        guard notificationThrottle.allows(at: ProcessInfo.processInfo.systemUptime) else { return }
        LiveNotification.post(
            title: String(localized: .notificationTitle), body: String(localized: .notificationBody)
        )
    }

    @discardableResult
    private func logMemory() -> Double? {
        guard let used = MemoryUsage.footprintMegabytes() else { return nil }
        peakMemory = max(peakMemory, used)
        logger.info("Memory \(used, format: .fixed(precision: 1), privacy: .public) MB, peak \(self.peakMemory, format: .fixed(precision: 1), privacy: .public) MB")
        return used
    }

    private static func downscaledFrame(from sampleBuffer: CMSampleBuffer) -> LumaImage? {
        CMSampleBufferGetImageBuffer(sampleBuffer).flatMap {
            LumaImage.downscaled(from: $0, maxDimension: Limits.frameDimension)
        }
    }

    /// Landscape games arrive as rotated portrait buffers.
    private static func orientation(of sampleBuffer: CMSampleBuffer) -> CGImagePropertyOrientation {
        let value = CMGetAttachment(
            sampleBuffer, key: RPVideoSampleOrientationKey as CFString, attachmentModeOut: nil
        ) as? NSNumber
        return value.flatMap { CGImagePropertyOrientation(rawValue: $0.uint32Value) } ?? .up
    }
}
