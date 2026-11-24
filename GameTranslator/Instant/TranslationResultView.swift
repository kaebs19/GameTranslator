import SwiftUI

struct TranslationResultView: View {
    let model: InstantTranslateModel
    @AppStorage("resultMode") private var mode = Mode.image
    @State private var saveState = SaveState.ready

    enum Mode: String { case image, list }

    private enum SaveState: Equatable {
        case ready, saving, saved
    }

    @State private var saveFailure: TranslateFailure?

    var body: some View {
        VStack(spacing: 0) {
            Picker(selection: $mode) {
                Text(.resultModeImage).tag(Mode.image)
                Text(.resultModeList).tag(Mode.list)
            } label: {
                Text(.resultMode)
            }
            .pickerStyle(.segmented)
            .padding()
            switch mode {
            case .image: imageView
            case .list: listView
            }
        }
        .safeAreaInset(edge: .bottom) { actions }
        .alert(Text(.errorTitle), isPresented: showsSaveFailure) {
            Button(role: .cancel) {} label: { Text(.commonOk) }
        } message: {
            if let saveFailure { Text(saveFailure.message) }
        }
    }

    @ViewBuilder private var imageView: some View {
        if let image = model.translatedImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel(Text(.resultImageLabel))
                .accessibilityValue(Text(verbatim: model.rows.compactMap(\.translation).joined(separator: "\n")))
        }
    }

    private var listView: some View {
        List(model.rows) { row in
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: row.translation ?? row.original)
                    .font(.headline)
                Text(verbatim: row.original)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .textSelection(.enabled)
        }
        .listStyle(.plain)
    }

    @ViewBuilder private var actions: some View {
        if let image = model.translatedImage {
            HStack(spacing: 12) {
                Button { save(image) } label: {
                    Label { Text(saveState == .saved ? .resultSaved : .resultSave) } icon: {
                        Image(systemName: saveState == .saved ? "checkmark" : "square.and.arrow.down")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(saveState != .ready)
                ShareLink(
                    item: Image(uiImage: image),
                    preview: SharePreview(Text(.resultImageLabel), image: Image(uiImage: image))
                ) {
                    Label { Text(.resultShare) } icon: { Image(systemName: "square.and.arrow.up") }
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding()
            .background(.bar)
        }
    }

    private var showsSaveFailure: Binding<Bool> {
        Binding { saveFailure != nil } set: { if !$0 { saveFailure = nil } }
    }

    private func save(_ image: UIImage) {
        guard let data = image.pngData() else { return }
        saveState = .saving
        Task {
            do {
                try await PhotoLibrary.save(data)
                saveState = .saved
            } catch {
                saveState = .ready
                saveFailure = error as? TranslateFailure ?? .translationFailed(error.localizedDescription)
            }
        }
    }
}
