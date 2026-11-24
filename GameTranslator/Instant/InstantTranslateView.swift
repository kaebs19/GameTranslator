import PhotosUI
import SwiftUI
import Translation

struct InstantTranslateView: View {
    @State private var model = InstantTranslateModel()
    @State private var pickedItem: PhotosPickerItem?
    @State private var showsSettings = false
    private let router = AppRouter.shared

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(Text(.instantTitle))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
        }
        .translationTask(model.configuration) { session in
            await model.runPendingJob { try await session.translateAll($0) }
        }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            pickedItem = nil
            model.translate { try await item.loadTransferable(type: Data.self) }
        }
        .onChange(of: router.request, initial: true) { _, _ in handleRouterRequest() }
        .sheet(isPresented: $showsSettings, onDismiss: model.retranslateIfSettingsChanged) {
            SettingsView()
        }
    }

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .idle:
            InstantStartView(pickedItem: $pickedItem, useLatest: model.translateLatestScreenshot)
        case .finished:
            TranslationResultView(model: model)
        case .failed(let failure):
            FailureView(failure: failure, model: model)
        case .loading, .recognizing, .translating:
            ProgressScreen(phase: model.phase)
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { showsSettings = true } label: {
                Label { Text(.settingsTitle) } icon: { Image(systemName: "gearshape") }
            }
        }
        if model.phase != .idle {
            ToolbarItem(placement: .topBarLeading) {
                Button { model.reset() } label: {
                    Label { Text(.instantNew) } icon: { Image(systemName: "xmark") }
                }
            }
        }
    }

    private func handleRouterRequest() {
        guard let request = router.takeRequest() else { return }
        showsSettings = false
        switch request {
        case .latestScreenshot: model.translateLatestScreenshot()
        case .image(let data): model.translate { data }
        }
    }
}

private struct InstantStartView: View {
    @Binding var pickedItem: PhotosPickerItem?
    let useLatest: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text(.instantIntro)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                Button(action: useLatest) {
                    WideLabel(title: .instantUseLatest, icon: "iphone.gen3")
                }
                .buttonStyle(.borderedProminent)
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    WideLabel(title: .instantPickPhoto, icon: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)
                Text(.instantPrivacy)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .controlSize(.large)
            .frame(maxWidth: 480)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.center)
    }
}

private struct WideLabel: View {
    let title: LocalizedStringResource
    let icon: String

    /// PhotosPicker builds its label outside the main actor.
    nonisolated init(title: LocalizedStringResource, icon: String) {
        self.title = title
        self.icon = icon
    }

    var body: some View {
        Label { Text(title) } icon: { Image(systemName: icon) }
            .frame(maxWidth: .infinity)
    }
}

private struct ProgressScreen: View {
    let phase: InstantTranslateModel.Phase

    var body: some View {
        ProgressView { Text(title) }
            .controlSize(.large)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var title: LocalizedStringResource {
        switch phase {
        case .recognizing: .progressRecognizing
        case .translating: .progressTranslating
        default: .progressLoading
        }
    }
}

private struct FailureView: View {
    let failure: TranslateFailure
    let model: InstantTranslateModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        ContentUnavailableView {
            Label { Text(.errorTitle) } icon: { Image(systemName: "exclamationmark.triangle") }
        } description: {
            Text(failure.message)
        } actions: {
            if failure.isFixedInSystemSettings {
                Button { openSystemSettings() } label: { Text(.errorOpenSettings) }
            } else if model.originalImage != nil {
                Button { model.retry() } label: { Text(.errorRetry) }
            }
            Button { model.reset() } label: { Text(.instantNew) }
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}
