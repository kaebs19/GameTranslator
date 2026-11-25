import SwiftUI

/// Large symbol with a short message, for start and onboarding screens.
struct HeroHeader: View {
    let icon: String
    let message: LocalizedStringResource

    var body: some View {
        VStack(spacing: AppSpacing.regular) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(message)
                .font(.title3)
                .multilineTextAlignment(.center)
        }
    }
}
