import SwiftUI

/// Full-screen error. Offers system Settings when that is where the fix is, otherwise retry.
struct ErrorStateView: View {
    let error: AppError
    var retry: (() -> Void)?
    let dismissTitle: LocalizedStringResource
    let dismiss: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        ContentUnavailableView {
            AppLabel(.errorTitle, icon: "exclamationmark.triangle")
        } description: {
            Text(error.message)
        } actions: {
            if error.isFixedInSystemSettings {
                AppButton(.errorOpenSettings, action: openSystemSettings)
            } else if let retry {
                AppButton(.errorRetry, action: retry)
            }
            AppButton(dismissTitle, action: dismiss)
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}
