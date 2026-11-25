import UIKit

/// Draws translated text over the original text boxes.
nonisolated struct ImageTranslationRenderer: Sendable {
    var isRightToLeft = true

    @concurrent
    func render(_ image: CGImage, overlays: [TextOverlay]) async -> CGImage? {
        let size = CGSize(width: image.width, height: image.height)
        let patches = overlays.map { overlay in
            let rect = Self.pixelRect(for: overlay.boundingBox, in: size)
            return Patch(
                text: overlay.text, rect: rect,
                maxFontSize: overlay.lineHeight.map { $0 * size.height * 1.2 } ?? rect.height,
                background: RegionColor.sample(image, in: rect)
            )
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIImage(cgImage: image).draw(in: CGRect(origin: .zero, size: size))
            // Every background goes first so a neighbour never covers drawn text.
            for patch in patches { fill(patch) }
            for patch in patches { drawText(of: patch) }
        }.cgImage
    }

    private struct Patch {
        let text: String
        let rect: CGRect
        let maxFontSize: CGFloat
        let background: RegionColor
    }

    /// Vision boxes hug the glyphs, so grow them to cover outlines and anti-aliasing.
    static func pixelRect(for box: CGRect, in size: CGSize) -> CGRect {
        let rect = CGRect(
            x: box.minX * size.width, y: box.minY * size.height,
            width: box.width * size.width, height: box.height * size.height
        )
        return rect
            .insetBy(dx: -rect.height * 0.15, dy: -rect.height * 0.1)
            .intersection(CGRect(origin: .zero, size: size))
            .integral
    }

    private func fill(_ patch: Patch) {
        patch.background.uiColor.setFill()
        UIBezierPath(roundedRect: patch.rect, cornerRadius: patch.rect.height * 0.12).fill()
    }

    private func drawText(of patch: Patch) {
        let area = patch.rect.insetBy(dx: patch.rect.height * 0.08, dy: 0)
        guard area.width > 1, area.height > 1 else { return }
        let fontSize = Self.fittingFontSize(
            for: patch.text, in: area.size, maximum: patch.maxFontSize, isRightToLeft: isRightToLeft
        )
        let string = Self.attributed(
            patch.text, fontSize: fontSize, color: patch.background.readableTextColor, isRightToLeft: isRightToLeft
        )
        let height = min(Self.measure(string, width: area.width).height, area.height)
        let target = CGRect(x: area.minX, y: area.midY - height / 2, width: area.width, height: height)
        string.draw(with: target, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
    }

    /// Largest font that fits; wraps to several lines when that allows a bigger size.
    static func fittingFontSize(
        for text: String, in size: CGSize, maximum: CGFloat = .infinity, isRightToLeft: Bool = true
    ) -> CGFloat {
        let limit = min(size.height, maximum)
        var low = max(6, limit * 0.3)
        var high = max(low, limit)
        while high - low > 0.5 {
            let middle = (low + high) / 2
            if fits(text, fontSize: middle, in: size, isRightToLeft: isRightToLeft) { low = middle } else { high = middle }
        }
        return low
    }

    static func fits(_ text: String, fontSize: CGFloat, in size: CGSize, isRightToLeft: Bool = true) -> Bool {
        let whole = attributed(text, fontSize: fontSize, color: .black, isRightToLeft: isRightToLeft)
        guard measure(whole, width: size.width).height <= size.height else { return false }
        // Without this a long word would be broken in the middle.
        return text.split(separator: " ").allSatisfy { word in
            attributed(String(word), fontSize: fontSize, color: .black, isRightToLeft: isRightToLeft).size().width <= size.width
        }
    }

    private static func measure(_ string: NSAttributedString, width: CGFloat) -> CGSize {
        string.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin], context: nil
        ).size
    }

    private static func attributed(
        _ text: String, fontSize: CGFloat, color: UIColor, isRightToLeft: Bool
    ) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.baseWritingDirection = isRightToLeft ? .rightToLeft : .leftToRight
        style.alignment = .center
        style.lineBreakMode = .byWordWrapping
        return NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: color,
            .paragraphStyle: style
        ])
    }
}
