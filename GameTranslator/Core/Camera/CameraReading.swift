import CoreGraphics

/// What one look at the box found.
nonisolated struct CameraReading: Sendable {
    let lines: [RecognizedLine]
    /// Height of the box in camera pixels, before any scaling. Tells how large the text really is.
    let pixelHeight: CGFloat
    /// From the frozen picture instead of the live one.
    let isStill: Bool
}

nonisolated enum CameraEvent: Sendable {
    case reading(CameraReading)
    /// The picture that is now frozen, upright.
    case still(CGImage)
}
