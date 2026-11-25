import CoreGraphics

/// Places where games usually put text.
enum BoxPreset: String, CaseIterable, Identifiable {
    case subtitles, dialog, menu, full

    var id: String { rawValue }

    var box: ScanBox {
        switch self {
        case .subtitles: ScanBox(rect: CGRect(x: 0.06, y: 0.48, width: 0.88, height: 0.16))
        case .dialog: ScanBox(rect: CGRect(x: 0.1, y: 0.28, width: 0.8, height: 0.3))
        case .menu: ScanBox(rect: CGRect(x: 0.06, y: 0.14, width: 0.5, height: 0.5))
        case .full: ScanBox(rect: CGRect(x: 0.02, y: 0.12, width: 0.96, height: 0.56))
        }
    }

    /// `nil` once the user changed the box by hand.
    static func matching(_ box: ScanBox) -> BoxPreset? {
        allCases.first { $0.box == box }
    }
}
