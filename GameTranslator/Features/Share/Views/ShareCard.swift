import SwiftUI

/// What a shared picture looks like.
struct ShareCard: View {
    static let width: CGFloat = 380
    /// A picture much longer than a screen helps nobody.
    static let maximumLines = 12

    let shared: SharedTranslation

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            ForEach(Array(shared.lines.prefix(Self.maximumLines).enumerated()), id: \.offset) { _, line in
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Text(verbatim: line.translation)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color.appTextPrimary)
                    if shared.includesOriginal {
                        Text(verbatim: line.original)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: AppSpacing.small * 2) {
                Image(.launchLogo)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 20)
                Text(.appName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.large)
        .background(Color.appSurface, in: .rect(cornerRadius: AppRadius.large))
        .overlay { RoundedRectangle(cornerRadius: AppRadius.large).strokeBorder(AppGradient.brand, lineWidth: 2) }
        .padding(AppSpacing.regular)
        .background(Color.appBackground)
        .frame(width: Self.width)
        // The reader of the picture follows the translation, not this phone's interface.
        .environment(\.layoutDirection, shared.pair.isTargetRightToLeft ? .rightToLeft : .leftToRight)
        .environment(\.dynamicTypeSize, .large)
    }
}
