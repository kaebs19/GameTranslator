import AVFoundation
import Foundation

/// Back camera. Frames are read in memory and dropped; nothing is recorded.
final class SystemCamera: NSObject, CameraProviding {
    private let reader = CameraFrameReader { try OCRService(mode: .accurate).recognize($0, orientation: $1, language: $2) }
    private let worker: CaptureWorker
    private let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)

    override init() {
        worker = CaptureWorker(reader: reader, device: device)
        super.init()
    }

    var session: AVCaptureSession? { device == nil ? nil : worker.session }
    var hasTorch: Bool { device?.hasTorch ?? false }

    func requestAccess() async -> Bool { await AVCaptureDevice.requestAccess(for: .video) }

    func start(language: AppLanguage) -> AsyncStream<CameraEvent> {
        // Two, so a reading never pushes out the frozen picture.
        let (stream, continuation) = AsyncStream<CameraEvent>.makeStream(bufferingPolicy: .bufferingNewest(2))
        reader.begin(language: language) { continuation.yield($0) }
        worker.start()
        return stream
    }

    func stop() {
        reader.end()
        worker.stop()
    }

    func setInterval(_ interval: TimeInterval) { reader.setInterval(interval) }
    func setReading(_ isReading: Bool) { reader.setReading(isReading) }
    func setFrozen(_ isFrozen: Bool) { reader.setFrozen(isFrozen) }
    func setRegion(_ region: CameraRegion) { reader.setRegion(region) }
    func setTorch(_ isOn: Bool) { worker.setTorch(isOn) }
    func setZoom(_ factor: CGFloat) { worker.setZoom(factor) }
}

/// Owns the capture session on its own queue, because starting it blocks.
/// `@unchecked`: everything after `init` runs on `queue`.
private nonisolated final class CaptureWorker: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()
    private static let maximumZoom: CGFloat = 6
    private let queue = DispatchQueue(label: "camera.session")
    private let frames = DispatchQueue(label: "camera.frames", qos: .userInitiated)
    private let reader: CameraFrameReader
    private let device: AVCaptureDevice?
    private var isConfigured = false

    init(reader: CameraFrameReader, device: AVCaptureDevice?) {
        self.reader = reader
        self.device = device
    }

    func start() {
        queue.async { [self] in
            configureIfNeeded()
            if isConfigured, !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func setTorch(_ isOn: Bool) {
        change { device in
            guard device.hasTorch, device.isTorchAvailable else { return }
            device.torchMode = isOn ? .on : .off
        }
    }

    func setZoom(_ factor: CGFloat) {
        change { $0.videoZoomFactor = min(max(factor, $0.minAvailableVideoZoomFactor), min(Self.maximumZoom, $0.maxAvailableVideoZoomFactor)) }
    }

    private func change(_ body: @escaping @Sendable (AVCaptureDevice) -> Void) {
        queue.async { [self] in
            guard let device, (try? device.lockForConfiguration()) != nil else { return }
            body(device)
            device.unlockForConfiguration()
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured, let device, let input = try? AVCaptureDeviceInput(device: device) else { return }
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        output.setSampleBufferDelegate(self, queue: frames)
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = session.canSetSessionPreset(.hd1920x1080) ? .hd1920x1080 : .high
        guard session.canAddInput(input), session.canAddOutput(output) else { return }
        session.addInput(input)
        session.addOutput(output)
        isConfigured = true
    }
}

nonisolated extension CaptureWorker: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) { reader.handle(buffer) }
    }
}
