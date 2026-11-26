import SwiftUI

/// Large digits, readable while typing on a remote.
struct PairingCodeView: View {
    let code: PairingCode
    /// No TV is receiving yet.
    let isWaiting: Bool

    var body: some View {
        Panel(title: .tvCodeTitle, note: .tvCodeNote) {
            VStack(spacing: AppSpacing.medium) {
                HStack(spacing: AppSpacing.medium) {
                    Text(verbatim: code.addressDigits)
                        .foregroundStyle(Color.appTextPrimary)
                    Text(verbatim: code.pin)
                        .foregroundStyle(Color.appAccent)
                }
                .font(.system(size: 34, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                // Digits are typed left to right in any language.
                .environment(\.layoutDirection, .leftToRight)
                .accessibilityElement()
                .accessibilityLabel(Text(.tvCodeTitle))
                .accessibilityValue(Text(verbatim: code.digits.map(String.init).joined(separator: " ")))
                if isWaiting {
                    HStack(spacing: AppSpacing.small) {
                        ProgressView()
                        Text(.tvWaiting)
                            .font(.footnote)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.regular)
        }
    }
}
