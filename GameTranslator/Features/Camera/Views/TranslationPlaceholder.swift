import SwiftUI

/// Marks where the translation will be, until there is one.
struct TranslationPlaceholder: View {
    let isTranslating: Bool
    var fills = false

    var body: some View {
        VStack(spacing: AppSpacing.small) {
            Text(.placeholderTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.appTextPrimary)
            Text(isTranslating ? .placeholderAim : .placeholderStart)
                .font(.caption)
                .foregroundStyle(Color.appTextSecondary)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.7)
        .padding(AppSpacing.medium)
        .frame(maxWidth: .infinity, maxHeight: fills ? .infinity : nil)
        .background(Color.appSurface.opacity(0.75), in: .rect(cornerRadius: AppRadius.medium))
        .dashedOutline(Color.appTextSecondary.opacity(0.5), radius: AppRadius.medium)
        .accessibilityElement(children: .combine)
    }
}
