import SwiftUI

/// Console game on the TV, read through its remote-play app on this phone, translation over the game.
struct RemotePlayGuideView: View {
    @State var viewModel: RemotePlayGuideViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// The official remote-play app on the App Store.
    private static let remoteAppURL = URL(string: "https://apps.apple.com/app/id1436192460")!

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.large) {
                    Text(title)
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color.appTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(message)
                        .foregroundStyle(Color.appTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    content
                }
                .padding(AppSpacing.regular)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
                .id(viewModel.step)
            }
            actions
        }
        .background(Color.appBackground.ignoresSafeArea())
        .tint(Color.appAccent)
        .animation(.snappy(duration: 0.25), value: viewModel.step)
        .onAppear(perform: viewModel.didEnter)
        .onDisappear(perform: viewModel.stop)
    }

    // MARK: Frame

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack {
                Text(.tvGuideStep(viewModel.number, viewModel.count))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.appTextSecondary)
                Spacer()
                AppButton(.commonClose, icon: "xmark") { dismiss() }
                    .buttonStyle(.icon)
            }
            HStack(spacing: 4) {
                ForEach(0..<viewModel.count, id: \.self) { index in
                    Capsule()
                        .fill(index < viewModel.number ? AnyShapeStyle(AppGradient.action) : AnyShapeStyle(Color.appOutline))
                        .frame(height: 4)
                }
            }
            .accessibilityHidden(true)
        }
        .padding(AppSpacing.regular)
    }

    private var actions: some View {
        VStack(spacing: AppSpacing.medium) {
            if !viewModel.canContinue, !viewModel.step.needsConfirmation, viewModel.step != .done {
                Label { Text(.remoteWaiting) } icon: { ProgressView() }
                    .font(.footnote)
                    .foregroundStyle(Color.appTextSecondary)
            }
            HStack(spacing: AppSpacing.medium) {
                if viewModel.canGoBack {
                    AppButton(.tvGuideBack, isWide: true, action: viewModel.back)
                        .buttonStyle(.secondary)
                }
                if viewModel.isLast {
                    AppButton(.tvGuideFinish, isWide: true) { dismiss() }
                        .buttonStyle(.primary)
                } else {
                    AppButton(.tvGuideNext, isWide: true, action: viewModel.next)
                        .buttonStyle(.primary)
                        .disabled(!viewModel.canContinue)
                }
            }
        }
        .padding(AppSpacing.regular)
        .background(Color.appBackground)
    }

    // MARK: Steps

    private var title: LocalizedStringResource {
        switch viewModel.step {
        case .console: .remoteConsoleTitle
        case .remoteApp: .remoteAppTitle
        case .tvApp: .remoteTvAppTitle
        case .pair: .tvGuidePairTitle
        case .region: .remoteRegionTitle
        case .broadcast: .remoteBroadcastTitle
        case .play: .remotePlayTitle
        case .done: .tvGuideDoneTitle
        }
    }

    private var message: LocalizedStringResource {
        switch viewModel.step {
        case .console: .remoteConsoleText
        case .remoteApp: .remoteAppText
        case .tvApp: .remoteTvAppText
        case .pair: .remotePairText
        case .region: .remoteRegionText
        case .broadcast: .remoteBroadcastText
        case .play: .remotePlayText
        case .done: .remoteDoneText
        }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.step {
        case .console:
            steps([.remoteConsole1, .remoteConsole2, .remoteConsole3, .remoteConsole4])
            note(.remoteConsoleNote)
            confirmation(.remoteConsoleDone)
        case .remoteApp:
            AppButton(.remoteAppOpen, icon: "arrow.down.app", isWide: true) { openURL(Self.remoteAppURL) }
                .buttonStyle(.secondary)
            steps([.remoteApp1, .remoteApp2, .remoteApp3])
            confirmation(.remoteAppDone)
        case .tvApp:
            codeBox(TVGuide.downloadAddress)
            steps([.tvGuideInstall1, .tvGuideInstall2, .remoteTvApp3, .remoteTvApp4])
            note(.tvGuideDownloadNote)
            confirmation(.remoteTvAppDone)
        case .pair: pairing
        case .region:
            RegionPicker(region: $viewModel.region)
            HStack(spacing: AppSpacing.small) {
                preset(.remoteRegionBottom, RemotePlaySettings.subtitles)
                preset(.remoteRegionMiddle, CGRect(x: 0.1, y: 0.4, width: 0.8, height: 0.22))
                preset(.remoteRegionTop, CGRect(x: 0.1, y: 0.06, width: 0.8, height: 0.22))
            }
            note(.remoteRegionNote)
            confirmation(.remoteRegionDone)
        case .broadcast:
            BroadcastButton(title: .liveStart)
                .frame(maxWidth: .infinity)
            steps([.remoteBroadcast1, .remoteBroadcast2])
            if viewModel.progress.isBroadcasting { success(.liveRunning) }
        case .play:
            steps([.remotePlay1, .remotePlay2, .remotePlay3])
            if viewModel.progress.linesRead > 0 {
                success(.remotePlayArrived)
            } else {
                note(.remotePlayNote)
                AppButton(.remotePlayShown, isWide: true) { viewModel.confirm() }
                    .buttonStyle(.secondary)
            }
        case .done:
            HStack {
                Spacer()
                Image(systemName: "checkmark.seal.fill").font(.system(size: 72)).foregroundStyle(Color.appSuccess)
                Spacer()
            }
            .accessibilityHidden(true)
            steps([.remoteDone1, .remoteDone2])
        }
    }

    @ViewBuilder private var pairing: some View {
        if let code = viewModel.code {
            codeBox(code)
        } else if viewModel.error {
            InlineErrorView(error: .cloudUnreachable) { Task { await viewModel.requestCode() } }
        } else {
            ProgressView().frame(maxWidth: .infinity)
        }
        steps([.remotePair1, .remotePair2])
        if viewModel.progress.isTVConnected { success(.tvGuidePaired) }
        note(.remotePairNote)
    }

    // MARK: Parts

    private func steps(_ items: [LocalizedStringResource]) -> some View {
        StepList(steps: items)
            .padding(AppSpacing.regular)
            .card(AppRadius.medium)
    }

    private func codeBox(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.system(size: 34, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.appAccent)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .environment(\.layoutDirection, .leftToRight)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.large)
            .card(AppRadius.medium)
    }

    private func note(_ text: LocalizedStringResource) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Color.appTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func success(_ text: LocalizedStringResource) -> some View {
        Label { Text(text) } icon: { Image(systemName: "checkmark.circle.fill") }
            .font(.headline)
            .foregroundStyle(Color.appSuccess)
    }

    /// The user says the step is done; the next one opens only then.
    private func confirmation(_ text: LocalizedStringResource) -> some View {
        let isDone = viewModel.progress.confirmed.contains(viewModel.step)
        return Button { viewModel.confirm(!isDone) } label: {
            HStack(spacing: AppSpacing.medium) {
                Image(systemName: isDone ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(isDone ? Color.appSuccess : Color.appTextSecondary)
                Text(text)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.appTextPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(AppSpacing.regular)
            .card(AppRadius.medium)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isDone ? .isSelected : [])
    }

    private func preset(_ title: LocalizedStringResource, _ rect: CGRect) -> some View {
        AppButton(title) { viewModel.setRegionPreset(rect) }
            .buttonStyle(.secondary)
            .font(.footnote)
    }
}
