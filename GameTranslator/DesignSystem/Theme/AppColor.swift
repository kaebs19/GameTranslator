import SwiftUI

/// One color as sRGB bytes, so contrast can be checked in tests.
nonisolated struct ColorToken: Equatable, Sendable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    init(_ hex: UInt32) {
        red = UInt8(hex >> 16 & 0xFF)
        green = UInt8(hex >> 8 & 0xFF)
        blue = UInt8(hex & 0xFF)
    }

    var color: Color {
        Color(.sRGB, red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }

    /// WCAG contrast, 1 to 21.
    func contrast(with other: ColorToken) -> Double {
        let (a, b) = (luminance, other.luminance)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    private var luminance: Double {
        func linear(_ value: UInt8) -> Double {
            let v = Double(value) / 255
            return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}

/// Palette taken from the icon: navy ground, blue → violet → pink for what matters.
/// Views use these names only, never raw colors.
nonisolated enum AppPalette {
    static let background = ColorToken(0x0A1020)
    static let surface = ColorToken(0x131B30)
    static let surfaceRaised = ColorToken(0x1D2743)
    static let outline = ColorToken(0x2C385A)
    static let textPrimary = ColorToken(0xF4F6FF)
    static let textSecondary = ColorToken(0xA7B1CF)
    static let accent = ColorToken(0x9A8CFF)
    static let brandBlue = ColorToken(0x3D63F5)
    static let brandViolet = ColorToken(0x7C4DEB)
    static let brandPink = ColorToken(0xEC4899)
    /// Pink light enough for symbols and text.
    static let pink = ColorToken(0xF472B6)
    static let success = ColorToken(0x34D399)
    static let warning = ColorToken(0xFBBF24)
}

extension Color {
    static let appBackground = AppPalette.background.color
    static let appSurface = AppPalette.surface.color
    static let appSurfaceRaised = AppPalette.surfaceRaised.color
    static let appOutline = AppPalette.outline.color
    static let appTextPrimary = AppPalette.textPrimary.color
    static let appTextSecondary = AppPalette.textSecondary.color
    static let appAccent = AppPalette.accent.color
    static let appPink = AppPalette.pink.color
    static let appSuccess = AppPalette.success.color
    static let appWarning = AppPalette.warning.color
}

enum AppGradient {
    /// Primary actions. White text stays readable across all of it.
    static let action = LinearGradient(
        colors: [AppPalette.brandBlue.color, AppPalette.brandViolet.color], startPoint: .leading, endPoint: .trailing
    )
    /// Decoration only: outlines and highlights, never behind text.
    static let brand = LinearGradient(
        colors: [AppPalette.brandBlue.color, AppPalette.brandViolet.color, AppPalette.brandPink.color],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

enum AppRadius {
    static let small: CGFloat = 12
    static let medium: CGFloat = 18
    static let large: CGFloat = 26
}
