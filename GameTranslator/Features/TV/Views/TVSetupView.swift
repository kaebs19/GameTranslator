import SwiftUI

/// Steps for one kind of TV, with the code it asks for.
struct TVSetupView: View {
    let kind: TVKind
    let viewModel: TVViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                HeroHeader(icon: kind.icon, message: kind.detail)
                StepList(steps: kind.steps)
                    .padding(AppSpacing.regular)
                    .card()
                if let note = kind.note {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(Color.appTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if kind.needsAddress, let address = viewModel.webAddress { addressPanel(address) }
                if let code = viewModel.pairingCode { PairingCodeView(code: code, isWaiting: !viewModel.canTest) }
            }
            .padding(AppSpacing.regular)
            .frame(maxWidth: AppSpacing.maxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(Text(kind.title))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func addressPanel(_ address: String) -> some View {
        Panel(title: .tvAddress) {
            Text(verbatim: address)
                .font(.title3.monospaced().weight(.semibold))
                .foregroundStyle(Color.appAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .environment(\.layoutDirection, .leftToRight)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity)
                .padding(AppSpacing.regular)
        }
    }
}
