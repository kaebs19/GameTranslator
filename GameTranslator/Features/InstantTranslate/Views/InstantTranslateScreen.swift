import SwiftUI

/// Shown over the home screen while an image is translated.
struct InstantTranslateScreen: View {
    let viewModel: InstantTranslateViewModel
    let makeResultViewModel: (TranslationResult) -> TranslationResultViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.appBackground.ignoresSafeArea())
                .navigationTitle(Text(.instantTitle))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
        }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingView(title: .progressLoading)
        case .recognizing:
            LoadingView(title: .progressRecognizing)
        case .translating:
            LoadingView(title: .progressTranslating)
        case .finished(let result):
            TranslationResultView(viewModel: makeResultViewModel(result))
                .id(result.id)
        case .failed(let error):
            ErrorStateView(error: error, retry: retryAction, dismissTitle: .commonClose, dismiss: { dismiss() })
        }
    }

    private var retryAction: (() -> Void)? {
        guard viewModel.canRetry else { return nil }
        return { viewModel.retry() }
    }

    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            AppButton(.commonClose, icon: "xmark") { dismiss() }
        }
    }
}
