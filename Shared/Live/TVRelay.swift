import CoreGraphics
import Foundation
import ImageIO

/// Reads the subtitle box of each frame and sends what changed to the TV through the server.
/// Runs inside the broadcast extension, where the app itself may be in the background.
/// Not thread-safe: use from one queue.
nonisolated final class TVRelay {
    typealias Recognize = (CGImage, CGImagePropertyOrientation, AppLanguage) throws -> [RecognizedLine]
    typealias Send = @Sendable ([String]) async -> Void

    /// Readings without text before the TV is cleared.
    static let emptyReadingsToClear = 3
    /// Two readings this alike are the same subtitle read twice.
    static let sameText = 0.85

    private let recognize: Recognize
    private let send: Send
    private var shown: [String] = []
    private var emptyReadings = 0
    private var sending: Task<Void, Never>?

    init(recognize: @escaping Recognize, send: @escaping Send) {
        self.recognize = recognize
        self.send = send
    }

    /// Returns the lines it sent, for the in-app transcript; empty when nothing changed.
    @discardableResult
    func process(
        _ frame: LumaImage, orientation: CGImagePropertyOrientation, region: CGRect, language: AppLanguage
    ) throws -> [String] {
        let rect = Self.bufferRect(for: region, orientation: orientation)
        guard let crop = frame.cropped(to: rect, maxDimension: 1600), let image = crop.makeCGImage() else { return [] }
        let lines = try recognize(image, orientation, language).filter { TextNormalizer.looksLikeText($0.text) }
        let isSideways = orientation == .left || orientation == .right
        let ratio = CGFloat(crop.width) / CGFloat(max(crop.height, 1))
        let texts = LineMerger.blocks(from: lines, aspectRatio: isSideways ? 1 / ratio : ratio).map(\.text)
        return update(texts)
    }

    /// Decides whether the TV needs a new picture.
    @discardableResult
    func update(_ texts: [String]) -> [String] {
        guard !texts.isEmpty else {
            emptyReadings += 1
            if emptyReadings == Self.emptyReadingsToClear, !shown.isEmpty {
                shown = []
                deliver([])
            }
            return []
        }
        emptyReadings = 0
        guard !Self.isSame(texts, shown) else { return [] }
        shown = texts
        deliver(texts)
        return texts
    }

    /// Only the newest picture matters: an older request still on its way is dropped.
    private func deliver(_ texts: [String]) {
        sending?.cancel()
        let send = send
        sending = Task { await send(texts) }
    }

    /// Letter by letter, ignoring case and punctuation: one misread letter is not a new subtitle.
    private static func isSame(_ a: [String], _ b: [String]) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy { first, second in
            let (x, y) = (Array(TextNormalizer.comparisonKey(first)), Array(TextNormalizer.comparisonKey(second)))
            let allowed = Int(Double(max(x.count, y.count)) * (1 - sameText))
            return EditDistance.isWithin(allowed, x, y)
        }
    }

    /// The region is given as the picture is seen; buffers can arrive turned.
    static func bufferRect(for region: CGRect, orientation: CGImagePropertyOrientation) -> CGRect {
        let (x, y, w, h) = (region.minX, region.minY, region.width, region.height)
        return switch orientation {
        case .right, .rightMirrored: CGRect(x: y, y: 1 - x - w, width: h, height: w)
        case .left, .leftMirrored: CGRect(x: 1 - y - h, y: x, width: h, height: w)
        case .down, .downMirrored: CGRect(x: 1 - x - w, y: 1 - y - h, width: w, height: h)
        default: region
        }
    }
}
