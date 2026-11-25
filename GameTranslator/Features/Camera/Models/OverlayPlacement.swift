import CoreGraphics

/// Where the translation goes: next to the box, never over the text being read if it can be helped.
nonisolated struct OverlayPlacement: Equatable {
    let frame: CGRect

    static let margin: CGFloat = 12
    /// The status label sits between the box and the translation.
    static let statusHeight: CGFloat = 30
    static let comfortableHeight: CGFloat = 96

    /// - Parameters:
    ///   - top: Space taken by controls at the top of the picture.
    ///   - bottom: Space taken by controls at its bottom.
    init(box: CGRect, in size: CGSize, top: CGFloat, bottom: CGFloat = 0) {
        let width = max(0, size.width - Self.margin * 2)
        let gap = Self.statusHeight + Self.margin
        let end = size.height - max(bottom, Self.margin)
        let below = end - (box.maxY + gap)
        let above = box.minY - Self.margin - top
        if below >= Self.comfortableHeight || (below >= above && below >= Self.comfortableHeight / 2) {
            frame = CGRect(x: Self.margin, y: box.maxY + gap, width: width, height: below)
        } else if above >= Self.comfortableHeight / 2 {
            frame = CGRect(x: Self.margin, y: top, width: width, height: above)
        } else {
            // The box fills the picture: cover its lower end.
            let height = min(Self.comfortableHeight * 1.5, max(0, end - top))
            frame = CGRect(x: Self.margin, y: end - height, width: width, height: height)
        }
    }
}
