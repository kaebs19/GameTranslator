import SwiftUI

/// Setting up a TV one step per screen: install, open, pair, test.
struct TVGuideView: View {
    let viewModel: TVViewModel
    @State var guide: TVGuide
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.large) {
                    Text(title)
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color.appTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let message {
                        Text(message)
                            .font(.body)
                            .foregroundStyle(Color.appTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    content
                }
                .padding(AppSpacing.regular)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
                .id(guide.number)
            }
            actions
        }
        .background(Color.appBackground.ignoresSafeArea())
        .tint(Color.appAccent)
        .animation(.snappy(duration: 0.25), value: guide)
        .onAppear {
            // Pairing needs the TV link on and listening.
            if !viewModel.isEnabled { viewModel.setEnabled(true) }
            viewModel.setVisible(true)
        }
    }

    // MARK: Frame

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack {
                Text(.tvGuideStep(guide.number, guide.count))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.appTextSecondary)
                Spacer()
                AppButton(.commonClose, icon: "xmark") { dismiss() }
                    .buttonStyle(.icon)
            }
            HStack(spacing: 4) {
                ForEach(0..<guide.count, id: \.self) { index in
                    Capsule()
                        .fill(index < guide.number ? AnyShapeStyle(AppGradient.action) : AnyShapeStyle(Color.appOutline))
                        .frame(height: 4)
                }
            }
            .accessibilityHidden(true)
        }
        .padding(AppSpacing.regular)
    }

    private var actions: some View {
        HStack(spacing: AppSpacing.medium) {
            if guide.canGoBack {
                AppButton(.tvGuideBack, isWide: true) { guide.back() }
                    .buttonStyle(.secondary)
            }
            if guide.isLast {
                AppButton(.tvGuideFinish, isWide: true) { dismiss() }
                    .buttonStyle(.primary)
            } else {
                AppButton(.tvGuideNext, isWide: true) { guide.next() }
                    .buttonStyle(.primary)
                    .disabled(!guide.canContinue(isConnected: viewModel.canTest))
            }
        }
        .padding(AppSpacing.regular)
        .background(Color.appBackground)
    }

    // MARK: Steps

    private var title: LocalizedStringResource {
        switch guide.step {
        case .choose: .tvGuideChooseTitle
        case .install: .tvGuideInstallTitle
        case .download: .tvGuideDownloadTitle
        case .open: .tvGuideOpenTitle
        case .pair, .browserPair: .tvGuidePairTitle
        case .address: .tvGuideAddressTitle
        case .unavailable: .tvGuideSoonTitle
        case .test: .tvGuideTestTitle
        case .done: .tvGuideDoneTitle
        }
    }

    private var message: LocalizedStringResource? {
        switch guide.step {
        case .choose: .tvGuideChooseText
        case .install: .tvGuideInstallText
        case .download: .tvGuideDownloadText
        case .open: .tvGuideOpenText
        case .pair: .tvGuidePairText
        case .browserPair: .tvGuideBrowserPairText
        case .address: .tvGuideAddressText
        case .unavailable: .tvGuideSoonText
        case .test: .tvGuideTestText
        case .done: .tvGuideDoneText
        }
    }

    @ViewBuilder private var content: some View {
        switch guide.step {
        case .choose: kinds
        case .install: steps([.tvGuideInstall1, .tvGuideInstall2, .tvGuideInstall3])
        case .download:
            codeBox(TVGuide.downloadAddress)
            steps([.tvGuideDownload1, .tvGuideDownload2, .tvGuideDownload3])
            note(.tvGuideDownloadNote)
        case .open:
            steps([.tvGuideOpen1, .tvGuideOpen2])
            note(.tvGuideOpenNote)
        case .pair, .browserPair: pairing
        case .address:
            if let address = viewModel.webAddress { codeBox(address) } else { ProgressView { Text(.tvStarting) } }
            steps([.tvGuideAddress1, .tvGuideAddress2])
        case .unavailable:
            AppButton(.tvGuideUseBrowser, icon: "safari", isWide: true) { guide.choose(.browser) }
                .buttonStyle(.secondary)
        case .test: test
        case .done: done
        }
    }

    private var kinds: some View {
        VStack(spacing: AppSpacing.medium) {
            ForEach(TVKind.allCases) { kind in
                Button { guide.choose(kind) } label: {
                    HStack(spacing: AppSpacing.medium) {
                        IconTile(icon: kind.icon, tint: .appAccent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kind.title).font(.body.weight(.semibold)).foregroundStyle(Color.appTextPrimary)
                            Text(kind.detail).font(.footnote).foregroundStyle(Color.appTextSecondary)
                        }
                        .multilineTextAlignment(.leading)
                        Spacer(minLength: AppSpacing.small)
                        Image(systemName: guide.kind == kind ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(guide.kind == kind ? Color.appAccent : Color.appTextSecondary)
                            .accessibilityHidden(true)
                    }
                    .padding(AppSpacing.regular)
                    .card(AppRadius.medium)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(guide.kind == kind ? .isSelected : [])
            }
        }
    }

    @ViewBuilder private var pairing: some View {
        if let code = viewModel.pairingCode {
            PairingCodeView(code: code, isWaiting: !viewModel.canTest)
        } else {
            ProgressView { Text(.tvStarting) }.frame(maxWidth: .infinity)
        }
        if viewModel.canTest {
            Label { Text(.tvGuidePaired) } icon: { Image(systemName: "checkmark.circle.fill") }
                .font(.headline)
                .foregroundStyle(Color.appSuccess)
        } else {
            note(.tvGuidePairNote)
        }
    }

    private var test: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            AppButton(.tvTest, icon: "play.tv", isWide: true) { viewModel.sendTest(sample) }
                .buttonStyle(.primary)
                .disabled(!viewModel.canTest)
            steps([.tvGuideTest1, .tvGuideTest2])
            note(.tvKindInputNote)
        }
    }

    private var done: some View {
        HStack {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.appSuccess)
                .accessibilityHidden(true)
            Spacer()
        }
        .padding(.vertical, AppSpacing.large)
    }

    // MARK: Parts

    private func steps(_ items: [LocalizedStringResource]) -> some View {
        StepList(steps: items)
            .padding(AppSpacing.regular)
            .card(AppRadius.medium)
    }

    private func codeBox(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.title2.monospaced().weight(.bold))
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

    private var sample: String {
        var resource = LocalizedStringResource.controlsSample
        resource.locale = locale
        return String(localized: resource)
    }
}
