import CoreGraphics
import Foundation
import ImageIO

/// Frame → changed? → OCR → unseen lines. Knows nothing about where frames come from.
/// Not thread-safe: use from one queue.
nonisolated final class LiveFrameProcessor {
    typealias Recognize = (CGImage, CGImagePropertyOrientation, AppLanguage) throws -> [RecognizedLine]

    enum Outcome: Equatable {
        case unchanged
        case noNewText
        case newLines([String])
    }

    private let recognize: Recognize
    private var deduper: TextDeduper
    private var lastFingerprint: FrameFingerprint?
    private var lastLanguage: AppLanguage?

    /// A small capacity keeps comparisons and memory cheap in the extension.
    init(deduper: TextDeduper = TextDeduper(capacity: 300), recognize: @escaping Recognize) {
        self.deduper = deduper
        self.recognize = recognize
    }

    /// Forgets everything seen, so text still on screen is reported again.
    func reset() {
        deduper.reset()
        lastFingerprint = nil
    }

    func process(
        _ image: LumaImage, orientation: CGImagePropertyOrientation, language: AppLanguage
    ) throws -> Outcome {
        guard let fingerprint = FrameFingerprint(image), let cgImage = image.makeCGImage() else { return .noNewText }
        if let lastFingerprint, lastLanguage == language, fingerprint.isSimilar(to: lastFingerprint) {
            return .unchanged
        }
        let lines = try recognize(cgImage, orientation, language)
        // Only after success, so a failed frame is tried again.
        lastFingerprint = fingerprint
        lastLanguage = language
        let added = deduper.merge(texts(from: lines, image, orientation))
        return added.isEmpty ? .noNewText : .newLines(added)
    }

    /// Subtitles are joined into sentences. Longer passages stay line by line: while they
    /// scroll, every position would produce a different paragraph and repeat its text.
    private func texts(
        from lines: [RecognizedLine], _ image: LumaImage, _ orientation: CGImagePropertyOrientation
    ) -> [String] {
        let readable = lines.filter { TextNormalizer.looksLikeText($0.text) }
        let isRotated = [.left, .right, .leftMirrored, .rightMirrored].contains(orientation)
        let ratio = CGFloat(image.width) / CGFloat(image.height)
        return LineMerger.blocks(from: readable, aspectRatio: isRotated ? 1 / ratio : ratio).flatMap { block in
            block.lines.count <= 3 ? [block.text] : block.lines.map(\.text)
        }
    }
}
