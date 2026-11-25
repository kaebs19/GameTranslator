import AVFoundation
import Foundation

/// Where in the frame to read, and how the frame is turned.
nonisolated struct CameraRegion: Equatable, Sendable {
    /// Normalized, top-left origin, in the sensor's orientation.
    var rect: CGRect
    /// Degrees that make the picture upright.
    var rotationAngle: CGFloat
}

protocol CameraProviding: AnyObject {
    /// For the preview; `nil` when there is no camera.
    var session: AVCaptureSession? { get }
    var hasTorch: Bool { get }
    func requestAccess() async -> Bool
    /// What the camera sees in the region, until the stream ends or `stop` is called.
    func start(language: AppLanguage) -> AsyncStream<CameraEvent>
    func stop()
    /// Shortest time between two readings.
    func setInterval(_ interval: TimeInterval)
    /// Off: the picture goes on but nothing is recognized.
    func setReading(_ isReading: Bool)
    /// Keeps the next frame and reads only that one.
    func setFrozen(_ isFrozen: Bool)
    func setRegion(_ region: CameraRegion)
    func setTorch(_ isOn: Bool)
    func setZoom(_ factor: CGFloat)
}
