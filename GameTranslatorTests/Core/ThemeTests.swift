import Testing
@testable import GameTranslator

struct ThemeTests {
    @Test func knownContrast() {
        #expect(abs(ColorToken(0xFFFFFF).contrast(with: ColorToken(0x000000)) - 21) < 0.01)
    }

    /// WCAG AA for normal text.
    @Test(arguments: [AppPalette.background, AppPalette.surface, AppPalette.surfaceRaised])
    func textIsReadableOnEverySurface(surface: ColorToken) {
        for text in [
            AppPalette.textPrimary, AppPalette.textSecondary, AppPalette.accent, AppPalette.pink, AppPalette.success, AppPalette.warning
        ] {
            #expect(text.contrast(with: surface) >= 4.5, "\(text) on \(surface)")
        }
    }

    @Test(arguments: [AppPalette.brandBlue, AppPalette.brandViolet])
    func whiteIsReadableOnTheActionGradient(color: ColorToken) {
        #expect(ColorToken(0xFFFFFF).contrast(with: color) >= 4.5)
    }
}
