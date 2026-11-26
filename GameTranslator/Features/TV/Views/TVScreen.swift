import SwiftUI

/// Turning the TV on, pairing it, and choosing how text looks there.
struct TVScreen: View {
    @Bindable var viewModel: TVViewModel
    /// False while something covers the screen, which closes pairing.
    let isActive: Bool
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.large) {
                    power
                    if viewModel.isEnabled { connection }
                    if !viewModel.tvs.isEmpty { paired }
                    setup
                    look
                }
                .padding(AppSpacing.regular)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .animation(.default, value: viewModel.state)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(Text(.tvTitle))
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(Color.appAccent)
        .onChange(of: isActive && scenePhase == .active, initial: true) { _, isVisible in
            viewModel.setVisible(isVisible)
        }
    }

    private var power: some View {
        Panel(title: .tvIntro, note: .tvSendNote) {
            PanelToggle(
                icon: "tv.badge.wifi", tint: .appAccent, title: .tvSend,
                isOn: Binding { viewModel.isEnabled } set: { viewModel.setEnabled($0) }
            )
        }
    }

    @ViewBuilder private var connection: some View {
        switch viewModel.state {
        case .failed(let error):
            InlineErrorView(error: error, retry: viewModel.retry)
        case .off, .starting:
            ProgressView { Text(.tvStarting) }
        case .ready:
            if let code = viewModel.pairingCode { PairingCodeView(code: code, isWaiting: !viewModel.canTest) }
        }
    }

    private var paired: some View {
        Panel(title: .tvPairedTitle) {
            ForEach(viewModel.tvs) { tv in
                if tv != viewModel.tvs.first { PanelDivider() }
                PairedTVRow(tv: tv, isConnected: viewModel.isConnected(tv)) { viewModel.forget(tv) }
            }
        }
    }

    private var setup: some View {
        Panel(title: .tvSetupTitle) {
            ForEach(TVKind.allCases) { kind in
                if kind != TVKind.allCases.first { PanelDivider() }
                NavigationLink {
                    TVSetupView(kind: kind, viewModel: viewModel)
                } label: {
                    TVKindRow(kind: kind)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var look: some View {
        Panel(title: .tvLookTitle, note: .tvLookNote) {
            VStack(alignment: .leading, spacing: AppSpacing.regular) {
                SegmentedPicker(title: .tvPosition, selection: $viewModel.look.position)
                SegmentedPicker(title: .controlsTextSize, selection: $viewModel.look.textSize)
            }
            .padding(AppSpacing.regular)
            PanelDivider()
            PanelToggle(
                icon: "textformat", tint: .appPink, title: .tvShowsOriginal, isOn: $viewModel.look.showsOriginal
            )
            PanelDivider()
            AppButton(.tvTest, icon: "play.tv", isWide: true) { viewModel.sendTest(sample) }
                .buttonStyle(.secondary)
                .disabled(!viewModel.canTest)
                .padding(AppSpacing.regular)
        }
    }

    private var sample: String {
        var resource = LocalizedStringResource.controlsSample
        resource.locale = locale
        return String(localized: resource)
    }
}

extension TVSettings.Position: SegmentOption {
    var title: LocalizedStringResource {
        switch self {
        case .top: .tvPositionTop
        case .bottom: .tvPositionBottom
        }
    }
}

private struct TVKindRow: View {
    let kind: TVKind

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            IconTile(icon: kind.icon, tint: .appAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.appTextPrimary)
                Text(kind.detail)
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

private struct PairedTVRow: View {
    let tv: PairedTV
    let isConnected: Bool
    let remove: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            IconTile(icon: "tv", tint: isConnected ? .appSuccess : .appTextSecondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: tv.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(1)
                Text(isConnected ? .tvConnected : .tvNotConnected)
                    .font(.footnote)
                    .foregroundStyle(isConnected ? Color.appSuccess : Color.appTextSecondary)
            }
            Spacer(minLength: AppSpacing.small)
            AppButton(.tvRemove, icon: "trash", role: .destructive, action: remove)
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.horizontal, AppSpacing.regular)
        .padding(.vertical, AppSpacing.small)
        .frame(minHeight: 60)
    }
}
