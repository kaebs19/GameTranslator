import CoreGraphics

/// The reading box, normalized to its container so it survives rotation.
struct ScanBox: Equatable {
    enum Handle: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
        case top, bottom, left, right

        var isCorner: Bool { [.topLeft, .topRight, .bottomLeft, .bottomRight].contains(self) }
        fileprivate var movesLeft: Bool { [.topLeft, .bottomLeft, .left].contains(self) }
        fileprivate var movesRight: Bool { [.topRight, .bottomRight, .right].contains(self) }
        fileprivate var movesTop: Bool { [.topLeft, .topRight, .top].contains(self) }
        fileprivate var movesBottom: Bool { [.bottomLeft, .bottomRight, .bottom].contains(self) }
    }

    static let minimumWidth: CGFloat = 0.25
    static let minimumHeight: CGFloat = 0.08
    static let standard = BoxPreset.subtitles.box

    private(set) var rect: CGRect

    init(rect: CGRect) {
        self.rect = rect
        self.rect = Self.clamped(rect)
    }

    func frame(in size: CGSize) -> CGRect {
        CGRect(
            x: rect.minX * size.width, y: rect.minY * size.height,
            width: rect.width * size.width, height: rect.height * size.height
        )
    }

    /// Offsets are in points of a container of `size`.
    func moved(by offset: CGSize, in size: CGSize) -> ScanBox {
        guard size.width > 0, size.height > 0 else { return self }
        return ScanBox(rect: rect.offsetBy(dx: offset.width / size.width, dy: offset.height / size.height))
    }

    /// The opposite side stays where it is.
    func resized(_ handle: Handle, by offset: CGSize, in size: CGSize) -> ScanBox {
        guard size.width > 0, size.height > 0 else { return self }
        let dx = offset.width / size.width, dy = offset.height / size.height
        var (left, right, top, bottom) = (rect.minX, rect.maxX, rect.minY, rect.maxY)
        if handle.movesLeft { left = min(max(0, left + dx), right - Self.minimumWidth) }
        if handle.movesRight { right = max(min(1, right + dx), left + Self.minimumWidth) }
        if handle.movesTop { top = min(max(0, top + dy), bottom - Self.minimumHeight) }
        if handle.movesBottom { bottom = max(min(1, bottom + dy), top + Self.minimumHeight) }
        return ScanBox(rect: CGRect(x: left, y: top, width: right - left, height: bottom - top))
    }

    private static func clamped(_ rect: CGRect) -> CGRect {
        let width = min(max(rect.width, minimumWidth), 1)
        let height = min(max(rect.height, minimumHeight), 1)
        return CGRect(
            x: min(max(rect.minX, 0), 1 - width), y: min(max(rect.minY, 0), 1 - height),
            width: width, height: height
        )
    }
}

/// Stored as "x y width height" so the box stays where the user left it.
extension ScanBox: RawRepresentable {
    init?(rawValue: String) {
        let values = rawValue.split(separator: " ").compactMap { Double($0) }
        guard values.count == 4, values.allSatisfy(\.isFinite) else { return nil }
        self.init(rect: CGRect(x: values[0], y: values[1], width: values[2], height: values[3]))
    }

    var rawValue: String {
        [rect.minX, rect.minY, rect.width, rect.height].map { String(Double($0)) }.joined(separator: " ")
    }
}
