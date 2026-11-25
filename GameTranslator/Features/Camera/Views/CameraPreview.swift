import AVFoundation
import SwiftUI

/// Live picture. Also translates the box on screen into the part of the sensor to read.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let box: CGRect
    let onRegion: (CameraRegion) -> Void

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.attach(session)
        return view
    }

    func updateUIView(_ view: CameraPreviewView, context: Context) {
        view.onRegion = onRegion
        view.box = box
    }
}

final class CameraPreviewView: UIView {
    var onRegion: ((CameraRegion) -> Void)?
    var box: CGRect = .zero {
        didSet { if box != oldValue { setNeedsLayout() } }
    }

    private var rotation: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?
    private var startObservation: NSKeyValueObservation?
    private var lastRegion: CameraRegion?

    override static var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    private var previewLayer: AVCaptureVideoPreviewLayer? { layer as? AVCaptureVideoPreviewLayer }

    func attach(_ session: AVCaptureSession) {
        previewLayer?.session = session
        previewLayer?.videoGravity = .resizeAspectFill
        // The input is added on another queue, so the device is only known once it runs.
        startObservation = session.observe(\.isRunning, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor in self?.sessionChanged() }
        }
    }

    private func sessionChanged() {
        if rotation == nil, let input = previewLayer?.session?.inputs.first as? AVCaptureDeviceInput {
            let coordinator = AVCaptureDevice.RotationCoordinator(device: input.device, previewLayer: previewLayer)
            rotation = coordinator
            rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview) { [weak self] _, _ in
                Task { @MainActor in self?.setNeedsLayout() }
            }
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let previewLayer, let rotation, let connection = previewLayer.connection else { return }
        let angle = rotation.videoRotationAngleForHorizonLevelPreview
        if connection.isVideoRotationAngleSupported(angle), connection.videoRotationAngle != angle {
            connection.videoRotationAngle = angle
        }
        guard !box.isEmpty, !bounds.isEmpty else { return }
        let region = CameraRegion(rect: previewLayer.metadataOutputRectConverted(fromLayerRect: box), rotationAngle: angle)
        guard region != lastRegion else { return }
        lastRegion = region
        onRegion?(region)
    }
}
