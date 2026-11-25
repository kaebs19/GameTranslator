// Not part of the simulator SDK.
#if canImport(ScreenCaptureKit)
import CoreMedia
import Foundation
import ImageIO
import ScreenCaptureKit
import os

/// Wraps the system picker and one full-screen stream.
/// `@unchecked`: the stream is behind a lock; callbacks arrive on system queues.
@available(iOS 27, *)
nonisolated final class ScreenCaptureSession: NSObject, @unchecked Sendable {
    enum Event: Sendable {
        case started
        /// `nil` when the user stopped it.
        case stopped(AppError?)
    }

    private let worker: ScreenFrameWorker
    private let onEvent: @Sendable (Event) -> Void
    private let stream = OSAllocatedUnfairLock<SCStream?>(uncheckedState: nil)
    private let frames = DispatchQueue(label: "capture.frames", qos: .utility)
    private let logger = Logger(subsystem: "GameTranslator", category: "capture")

    init(worker: ScreenFrameWorker, onEvent: @escaping @Sendable (Event) -> Void) {
        self.worker = worker
        self.onEvent = onEvent
    }

    static var isAvailable: Bool { SCContentSharingPicker.shared.isAvailable }

    /// Shows the system sheet; capture begins only after the user agrees there.
    @MainActor
    func present() {
        let picker = SCContentSharingPicker.shared
        var configuration = SCContentSharingPickerConfiguration()
        configuration.showsMicrophoneControl = false
        picker.defaultConfiguration = configuration
        picker.remove(self)
        picker.add(self)
        picker.isActive = true
        picker.present()
    }

    func stop() {
        guard let current = stream.withLockUnchecked({ $0 }) else { return }
        // Only compared by identity in the callback.
        nonisolated(unsafe) let active = current
        active.stopCapture { [weak self] _ in self?.finish(active, error: nil) }
    }

    private func begin(with filter: SCContentFilter) {
        nonisolated(unsafe) let new = SCStream(filter: filter, configuration: SCStreamConfiguration(), delegate: self)
        do {
            try new.addStreamOutput(self, type: .screen, sampleHandlerQueue: frames)
        } catch {
            return onEvent(.stopped(Self.appError(error)))
        }
        stream.withLockUnchecked { $0 = new }
        new.startCapture { [weak self] error in
            if let error {
                self?.finish(new, error: error)
            } else {
                self?.logger.info("Capture started")
                self?.onEvent(.started)
            }
        }
    }

    /// Stopping can be reported twice, by the completion and by the delegate.
    private func finish(_ finished: SCStream, error: (any Error)?) {
        let wasCurrent = stream.withLockUnchecked { current in
            guard current === finished else { return false }
            current = nil
            return true
        }
        guard wasCurrent else { return }
        logger.info("Capture stopped: \(error.map { "\(($0 as NSError).domain) \(($0 as NSError).code)" } ?? "by user", privacy: .public)")
        onEvent(.stopped(error.flatMap(Self.appError)))
    }

    /// The user ending or declining capture is not a failure.
    private static func appError(_ error: any Error) -> AppError? {
        let code = (error as? SCStreamError)?.code
        if code == .userStopped || code == .userDeclined { return nil }
        return .captureFailed(error.localizedDescription)
    }
}

@available(iOS 27, *)
nonisolated extension ScreenCaptureSession: SCContentSharingPickerObserver {
    func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        onEvent(.stopped(nil))
    }

    func contentSharingPicker(
        _ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?
    ) {
        begin(with: filter)
    }

    func contentSharingPickerStartDidFailWithError(_ error: any Error) {
        onEvent(.stopped(Self.appError(error)))
    }
}

@available(iOS 27, *)
nonisolated extension ScreenCaptureSession: SCStreamDelegate, SCStreamOutput {
    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        finish(stream, error: error)
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        let info = Self.frameInfo(sampleBuffer)
        // Idle and blank callbacks repeat the previous picture.
        if let status = info?[.status] as? Int, status != SCFrameStatus.complete.rawValue,
           status != SCFrameStatus.started.rawValue { return }
        let orientation = (info?[.videoOrientation] as? NSNumber)
            .flatMap { CGImagePropertyOrientation(rawValue: $0.uint32Value) } ?? .up
        worker.handle(buffer, orientation: orientation)
    }

    private static func frameInfo(_ sampleBuffer: CMSampleBuffer) -> [SCStreamFrameInfo: Any]? {
        let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
        return (attachments as? [[SCStreamFrameInfo: Any]])?.first
    }
}
#endif
