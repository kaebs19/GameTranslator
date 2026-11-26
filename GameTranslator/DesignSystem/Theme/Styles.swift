import SwiftUI

/// Main action of a screen. One per screen.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(AppGradient.action, in: .rect(cornerRadius: AppRadius.medium))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.appTextPrimary)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Color.appSurfaceRaised, in: .rect(cornerRadius: AppRadius.medium))
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
    }
}

/// Round icon for headers.
struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.iconOnly)
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.appTextPrimary)
            // A symbol in a fixed circle: growing further would spill out of it.
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .frame(width: 44, height: 44)
            .background(Color.appSurfaceRaised, in: .circle)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// Icon over a picture: no background, so what is behind it stays visible.
struct PictureIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.iconOnly)
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.appTextPrimary)
            // Keeps the symbol readable on bright pictures.
            .shadow(color: .black.opacity(0.8), radius: 3)
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .frame(width: 44, height: 44)
            .contentShape(.rect)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

extension ButtonStyle where Self == IconButtonStyle {
    static var icon: IconButtonStyle { IconButtonStyle() }
}

extension ButtonStyle where Self == PictureIconButtonStyle {
    static var pictureIcon: PictureIconButtonStyle { PictureIconButtonStyle() }
}

extension View {
    /// Separate strokes: marks a place without closing it off.
    func dashedOutline(_ color: Color, radius: CGFloat) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(color, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
        }
    }

    /// Raised panel.
    func card(_ radius: CGFloat = AppRadius.large) -> some View {
        background(Color.appSurface, in: .rect(cornerRadius: radius))
            .overlay { RoundedRectangle(cornerRadius: radius).strokeBorder(Color.appOutline, lineWidth: 1) }
    }

    /// Replaces the system grey of forms and lists.
    func appScreenBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Color.appBackground.ignoresSafeArea())
    }
}
