import SwiftUI

/// One way to bring a game's text in, as a row and as its own page of steps.

struct ConnectRow: View {
    let guide: ConnectGuide

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            IconTile(icon: guide.icon, tint: guide.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(guide.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.appTextPrimary)
                Text(guide.detail)
                    .font(.footnote)
                    .foregroundStyle(Color.appTextSecondary)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: AppSpacing.small)
            PanelValue(text: nil, style: .link)
        }
        .padding(AppSpacing.regular)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

struct ConnectGuideView: View {
    let guide: ConnectGuide
    let action: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                HeroHeader(icon: guide.icon, message: guide.detail)
                StepList(steps: guide.steps)
                    .padding(AppSpacing.regular)
                    .card()
                AppButton(guide.actionTitle, icon: guide.actionIcon, isWide: true, action: action)
                    .buttonStyle(.primary)
            }
            .padding(AppSpacing.regular)
            .frame(maxWidth: AppSpacing.maxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(Text(guide.title))
        .navigationBarTitleDisplayMode(.inline)
    }
}
