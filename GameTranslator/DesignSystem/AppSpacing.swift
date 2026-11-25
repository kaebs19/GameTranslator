import CoreGraphics

nonisolated enum AppSpacing {
    static let small: CGFloat = 4
    static let medium: CGFloat = 12
    static let regular: CGFloat = 16
    static let large: CGFloat = 24
    /// Keeps columns readable on iPad.
    static let maxContentWidth: CGFloat = 480
}
