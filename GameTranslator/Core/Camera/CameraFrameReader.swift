import CoreImage
import CoreVideo
import Foundation
import ImageIO
import os

/// Reads the text inside the region, a few times a second from the live picture
/// or once per change from a frozen one.
/// `@unchecked`: state is behind a lock.
nonisolated final class CameraFrameReader: @unchecked Sendable {
    typealias Recognize = @Sendable (CGImage, CGImagePropertyOrientation, AppLanguage) throws -> [RecognizedLine]

    private struct State {
        var gate = FrameGate(interval: 0.4)
        var region = CameraRegion(rect: CGRect(x: 0, y: 0, width: 1, height: 1), rotationAngle: 90)
        var language = AppLanguage.english
        var isReading = false
        var wantsStill = false
        var still: LumaImage?
        /// Only the newest scheduled reading of a still counts.
        var stillRequest = 0
        var onEvent: (@Sendable (CameraEvent) -> Void)?
    }

    private static let cropDimension = 1280
    /// Dragging the box over a frozen picture should not read every position on the way.
    private static let stillDelay: TimeInterval = 0.25

    private let state = OSAllocatedUnfairLock(uncheckedState: State())
    private let queue = DispatchQueue(label: "camera.ocr", qos: .userInitiated)
    private let recognize: Recognize
    private let imageContext = CIContext()

    init(recognize: @escaping Recognize) {
        self.recognize = recognize
    }

    func setRegion(_ region: CameraRegion) {
        let isFrozen = state.withLockUnchecked { state in
            state.region = region
            return state.still != nil
        }
        if isFrozen { scheduleStill(after: Self.stillDelay) }
    }

    /// Shortest time between two live readings.
    func setInterval(_ interval: TimeInterval) { state.withLockUnchecked { $0.gate.interval = interval } }

    func setReading(_ isReading: Bool) { state.withLockUnchecked { $0.isReading = isReading } }

    func setFrozen(_ isFrozen: Bool) {
        state.withLockUnchecked { state in
            state.wantsStill = isFrozen
            state.still = nil
            state.stillRequest += 1
        }
    }

    func begin(language: AppLanguage, onEvent: @escaping @Sendable (CameraEvent) -> Void) {
        state.withLockUnchecked {
            $0.language = language
            $0.onEvent = onEvent
        }
    }

    func end() {
        setFrozen(false)
        state.withLockUnchecked { $0.onEvent = nil }
    }

    func handle(_ buffer: CVPixelBuffer) {
        let takesStill = state.withLockUnchecked { state in
            guard state.onEvent != nil, state.wantsStill else { return false }
            state.wantsStill = false
            return true
        }
        if takesStill { return keepStill(buffer) }

        let now = ProcessInfo.processInfo.systemUptime
        let accepted = state.withLockUnchecked {
            $0.isReading && $0.still == nil && $0.onEvent != nil && $0.gate.begin(at: now)
        }
        guard accepted else { return }
        let current = state.withLockUnchecked { $0 }
        guard let crop = LumaImage.downscaled(
            from: buffer, region: current.region.rect, maxDimension: Self.cropDimension
        ) else { return state.withLockUnchecked { $0.gate.end() } }
        let size = CGSize(
            width: CGFloat(CVPixelBufferGetWidth(buffer)) * current.region.rect.width,
            height: CGFloat(CVPixelBufferGetHeight(buffer)) * current.region.rect.height
        )
        queue.async { [self] in
            read(crop, cropSize: size, with: current, isStill: false)
            state.withLockUnchecked { $0.gate.end() }
        }
    }

    // MARK: Frozen picture

    private func keepStill(_ buffer: CVPixelBuffer) {
        guard let luma = LumaImage.downscaled(
            from: buffer, region: CGRect(x: 0, y: 0, width: 1, height: 1), maxDimension: 4096
        ) else { return }
        let current = state.withLockUnchecked { state in
            state.still = luma
            return state
        }
        // Made from this very frame, so what is shown is exactly what is read.
        let upright = CIImage(cvPixelBuffer: buffer).oriented(Self.orientation(forAngle: current.region.rotationAngle))
        if let image = imageContext.createCGImage(upright, from: upright.extent) { current.onEvent?(.still(image)) }
        scheduleStill(after: 0)
    }

    private func scheduleStill(after delay: TimeInterval) {
        let request = state.withLockUnchecked { state in
            state.stillRequest += 1
            return state.stillRequest
        }
        queue.asyncAfter(deadline: .now() + delay) { [self] in
            let current = state.withLockUnchecked { $0 }
            guard current.stillRequest == request, let still = current.still,
                  let crop = still.cropped(to: current.region.rect, maxDimension: Self.cropDimension) else { return }
            let size = CGSize(
                width: CGFloat(still.width) * current.region.rect.width,
                height: CGFloat(still.height) * current.region.rect.height
            )
            read(crop, cropSize: size, with: current, isStill: true)
        }
    }

    // MARK: Recognition

    private func read(_ crop: LumaImage, cropSize: CGSize, with current: State, isStill: Bool) {
        autoreleasepool {
            let orientation = Self.orientation(forAngle: current.region.rotationAngle)
            guard let image = crop.makeCGImage(),
                  let lines = try? recognize(image, orientation, current.language) else { return }
            let isSideways = orientation == .right || orientation == .left
            let reading = CameraReading(
                lines: lines, pixelHeight: isSideways ? cropSize.width : cropSize.height, isStill: isStill
            )
            state.withLockUnchecked { $0.onEvent }?(.reading(reading))
        }
    }

    static func orientation(forAngle angle: CGFloat) -> CGImagePropertyOrientation {
        switch (Int(angle.rounded()) % 360 + 360) % 360 {
        case 45..<135: .right
        case 135..<225: .down
        case 225..<315: .left
        default: .up
        }
    }
}
