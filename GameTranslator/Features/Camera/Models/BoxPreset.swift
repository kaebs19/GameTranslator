import CoreGraphics

/// Places where games usually put text.
enum BoxPreset: String, CaseIterable, Identifiable {
    case subtitles, dialog, menu, full

    var id: String { rawValue }

    var box: ScanBox {
        switch self {
        case .subtitles: ScanBox(rect: CGRect(x: 0.05, y: 0.64, width: 0.9, height: 0.22))
        case .dialog: ScanBox(rect: CGRect(x: 0.08, y: 0.34, width: 0.84, height: 0.4))
        case .menu: ScanBox(rect: CGRect(x: 0.05, y: 0.18, width: 0.55, height: 0.66))
        case .full: ScanBox(rect: CGRect(x: 0.03, y: 0.16, width: 0.94, height: 0.72))
        }
    }

    /// `nil` once the user changed the box by hand.
    static func matching(_ box: ScanBox) -> BoxPreset? {
        allCases.first { $0.box == box }
    }
}
