import CoreGraphics

/// Text to paint over one region of the original image.
nonisolated struct TextOverlay: Sendable {
    let text: String
    /// Normalized, top-left origin.
    let boundingBox: CGRect
    /// Normalized height of one original line; keeps a short translation of a tall block from growing huge.
    var lineHeight: CGFloat?
}
