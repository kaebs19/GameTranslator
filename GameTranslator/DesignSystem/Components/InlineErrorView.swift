import SwiftUI

/// Error shown inside a screen that keeps its content.
struct InlineErrorView: View {
    let error: AppError
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: AppSpacing.small) {
            Label { Text(error.message) } icon: { Image(systemName: "exclamationmark.triangle") }
                .font(.subheadline)
                .foregroundStyle(.orange)
            if let retry {
                AppButton(.errorRetry, action: retry)
            }
        }
    }
}
