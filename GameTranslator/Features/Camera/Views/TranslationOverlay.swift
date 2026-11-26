import SwiftUI

/// Translation with its actions. Takes only the height it needs, or all of it when `fills` is on.
struct TranslationOverlay: View {
    let viewModel: CameraViewModel
    var fills = false
    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if fills {
                ScrollView { content }
            } else {
                ViewThatFits(in: .vertical) {
                    content
                    ScrollView { content }
                }
            }
            if !viewModel.translatedText.isEmpty { actions }
        }
        .background(Color.appSurface.opacity(0.94), in: .rect(cornerRadius: AppRadius.medium))
        .dashedOutline(Color.appTextSecondary.opacity(0.5), radius: AppRadius.medium)
        .onChange(of: viewModel.translatedText) { didCopy = false }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            if let error = viewModel.translationError {
                InlineErrorView(error: error, retry: viewModel.retryTranslation)
            }
            ForEach(viewModel.displayed) { item in
                TranslatedTextRow(
                    original: item.original, translation: item.translation,
                    showsOriginal: viewModel.current.reading.showsOriginal,
                    font: viewModel.current.reading.textSize.font
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.medium)
    }

    private var actions: some View {
        HStack(spacing: AppSpacing.small) {
            action(didCopy ? .overlayCopied : .historyCopy, icon: didCopy ? "checkmark" : "doc.on.doc") {
                UIPasteboard.general.string = viewModel.translatedText
                didCopy = true
            }
            action(
                viewModel.isSpeaking ? .overlayStopSpeaking : .overlaySpeak,
                icon: viewModel.isSpeaking ? "stop.circle" : "speaker.wave.2", run: viewModel.toggleSpeaking
            )
            if let shared = viewModel.shared {
                ShareTranslationMenu(shared: shared) {
                    symbol(.resultShare, icon: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            action(.liveClear, icon: "xmark", run: viewModel.clearResult)
        }
        .padding(.horizontal, AppSpacing.small)
    }

    private func action(
        _ title: LocalizedStringResource, icon: String, run: @escaping () -> Void
    ) -> some View {
        Button(action: run) { symbol(title, icon: icon) }
            .buttonStyle(.plain)
    }

    private func symbol(_ title: LocalizedStringResource, icon: String) -> some View {
        AppLabel(title, icon: icon)
            .labelStyle(.iconOnly)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.appAccent)
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .frame(width: 44, height: 40)
            .contentShape(.rect)
    }
}

extension ReadingSettings.TextSize {
    var font: Font {
        switch self {
        case .small: .body.weight(.semibold)
        case .medium: .title3.weight(.semibold)
        case .large: .title.weight(.semibold)
        }
    }
}
