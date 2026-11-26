import AppIntents
import SwiftUI

/// Where the game is, where the translation shows, and whether all of it is ready.
struct DevicesScreen: View {
    let tv: TVViewModel
    let isActive: Bool
    let isBroadcasting: Bool
    /// Read when the screen appears, since settings change elsewhere.
    let usesEnhancedTranslation: () -> Bool
    let perform: (ConnectGuide.Action) -> Void
    let openSettings: () -> Void
    /// Set from outside to open the TV guide, for example after the introduction.
    @Binding var opensGuide: Bool
    @State private var guide: TVGuide?
    @State private var usesEnhanced = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.large) {
                    status
                    console
                    TVSection(viewModel: tv, isActive: isActive, guide: $guide)
                    phone
                }
                .padding(AppSpacing.regular)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(Text(.devicesTitle))
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(Color.appAccent)
        .onChange(of: isActive, initial: true) { _, active in
            if active { usesEnhanced = usesEnhancedTranslation() }
        }
        .onChange(of: opensGuide, initial: true) { _, opens in
            guard opens else { return }
            opensGuide = false
            guide = TVGuide(kind: .android)
        }
    }

    private var readiness: DeviceReadiness {
        DeviceReadiness(
            isBroadcasting: isBroadcasting, pairedTVs: tv.tvs.count,
            connectedTVs: tv.tvs.filter(tv.isConnected).count, usesEnhancedTranslation: usesEnhanced
        )
    }

    // MARK: Status

    private var status: some View {
        Panel(title: .devicesStatus) {
            Button { perform(isBroadcasting ? .broadcast : .camera) } label: {
                StatusRow(
                    icon: isBroadcasting ? "dot.radiowaves.left.and.right" : "camera.viewfinder",
                    title: .devicesReading, value: isBroadcasting ? .liveRunning : .devicesReadingCamera,
                    level: readiness.reading
                )
            }
            PanelDivider()
            Button { if readiness.tv == .off { guide = TVGuide() } } label: {
                StatusRow(icon: "tv", title: .tvTitle, value: tvValue, level: readiness.tv)
            }
            PanelDivider()
            Button(action: openSettings) {
                StatusRow(
                    icon: "sparkles", title: .serverTitle,
                    value: usesEnhanced ? .commonOn : .commonOff, level: readiness.enhanced
                )
            }
        }
        .buttonStyle(.plain)
    }

    private var tvValue: LocalizedStringResource {
        switch readiness.tv {
        case .off: .devicesTvNone
        case .attention: .tvNotConnected
        case .ready: .tvConnected
        }
    }

    // MARK: Sources

    private var console: some View {
        Panel(title: .connectWays, note: .connectWaysNote) {
            ForEach([ConnectGuide.screen, .stream]) { item in
                if item != .screen { PanelDivider() }
                guideLink(item)
            }
        }
    }

    private var phone: some View {
        Panel(title: .devicesPhone, note: .connectShortcutsNote) {
            guideLink(.phone)
            PanelDivider()
            VStack(alignment: .leading, spacing: AppSpacing.regular) {
                Text(.connectShortcuts)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.appTextPrimary)
                StepList(steps: [.connectShortcutsStep1, .connectShortcutsStep2, .connectShortcutsStep3])
                ShortcutsLink()
                    .shortcutsLinkStyle(.darkOutline)
                    .frame(maxWidth: .infinity)
            }
            .padding(AppSpacing.regular)
        }
    }

    private func guideLink(_ item: ConnectGuide) -> some View {
        NavigationLink {
            ConnectGuideView(guide: item) { perform(item.action) }
        } label: {
            ConnectRow(guide: item)
        }
        .buttonStyle(.plain)
    }
}

/// One line of the readiness card.
private struct StatusRow: View {
    let icon: String
    let title: LocalizedStringResource
    let value: LocalizedStringResource
    let level: DeviceReadiness.Level

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            IconTile(icon: icon, tint: color)
            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(Color.appTextPrimary)
            Spacer(minLength: AppSpacing.small)
            Label {
                Text(value)
            } icon: {
                Image(systemName: symbol)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(color)
            .labelStyle(.titleAndIcon)
        }
        .padding(AppSpacing.regular)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch level {
        case .ready: .appSuccess
        case .attention: .appWarning
        case .off: .appTextSecondary
        }
    }

    private var symbol: String {
        switch level {
        case .ready: "checkmark.circle.fill"
        case .attention: "exclamationmark.circle.fill"
        case .off: "circle"
        }
    }
}
