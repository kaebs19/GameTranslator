import CoreGraphics
import Foundation

/// One line of text found on screen.
nonisolated struct RecognizedLine: Identifiable, Hashable, Sendable {
    let id: UUID
    let text: String
    /// Normalized (0...1) box with a **top-left** origin, ready for UIKit drawing.
    let boundingBox: CGRect
    let confidence: Float

    init(id: UUID = UUID(), text: String, boundingBox: CGRect, confidence: Float = 1) {
        self.id = id
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
    }
}
