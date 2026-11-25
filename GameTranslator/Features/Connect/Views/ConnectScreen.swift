import AppIntents
import SwiftUI

/// Where the user plays decides how text reaches the app.
struct ConnectScreen: View {
    let isBroadcasting: Bool
    let perform: (ConnectGuide.Action) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.large) {
                    if isBroadcasting { broadcastStatus }
                    ways
                    shortcuts
                }
                .padding(AppSpacing.regular)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(Text(.connectTitle))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var broadcastStatus: some View {
        Button { perform(.broadcast) } label: {
            PanelRow(icon: "dot.radiowaves.left.and.right", tint: .appSuccess, title: .liveRunning) {
                PanelValue(text: nil, style: .link)
            }
        }
        .buttonStyle(.plain)
        .card()
    }

    private var ways: some View {
        Panel(title: .connectWays, note: .connectWaysNote) {
            ForEach(ConnectGuide.allCases) { guide in
                if guide != ConnectGuide.allCases.first { PanelDivider() }
                NavigationLink {
                    ConnectGuideView(guide: guide) { perform(guide.action) }
                } label: {
                    ConnectRow(guide: guide)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var shortcuts: some View {
        Panel(title: .connectShortcuts, note: .connectShortcutsNote) {
            VStack(alignment: .leading, spacing: AppSpacing.regular) {
                StepList(steps: [.connectShortcutsStep1, .connectShortcutsStep2, .connectShortcutsStep3])
                ShortcutsLink()
                    .shortcutsLinkStyle(.darkOutline)
                    .frame(maxWidth: .infinity)
            }
            .padding(AppSpacing.regular)
        }
    }
}

private struct ConnectRow: View {
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

private struct ConnectGuideView: View {
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
