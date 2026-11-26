import SwiftUI

struct TranslationResultView: View {
    enum Mode: String, SegmentOption {
        case image, list

        var title: LocalizedStringResource {
            switch self {
            case .image: .resultModeImage
            case .list: .resultModeList
            }
        }
    }

    @State private var viewModel: TranslationResultViewModel
    @AppStorage("resultMode") private var mode = Mode.image

    init(viewModel: TranslationResultViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            SegmentedPicker(title: .resultMode, selection: $mode)
                .padding()
            switch mode {
            case .image: imageView
            case .list: listView
            }
        }
        .bottomActionBar { actions }
        .errorAlert($viewModel.saveError)
    }

    private var imageView: some View {
        Image(uiImage: viewModel.result.image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel(Text(.resultImageLabel))
            .accessibilityValue(Text(verbatim: viewModel.result.translatedText))
    }

    private var listView: some View {
        List(viewModel.result.rows) { row in
            TranslatedTextRow(original: row.original, translation: row.translation)
        }
        .listStyle(.plain)
    }

    @ViewBuilder private var actions: some View {
        let isSaved = viewModel.saveState == .saved
        let image = Image(uiImage: viewModel.result.image)
        AppButton(
            isSaved ? .resultSaved : .resultSave,
            icon: isSaved ? "checkmark" : "square.and.arrow.down", isWide: true
        ) {
            Task { await viewModel.save() }
        }
        .disabled(viewModel.saveState != .ready)
        Menu {
            ShareLink(item: image, preview: SharePreview(Text(.resultImageLabel), image: image)) {
                AppLabel(.resultImageLabel, icon: "photo")
            }
            if let shared = viewModel.result.shared {
                ShareLink(item: shared.text) {
                    AppLabel(.shareAsText, icon: "text.alignright")
                }
            }
        } label: {
            AppLabel(.resultShare, icon: "square.and.arrow.up", isWide: true)
        }
    }
}
