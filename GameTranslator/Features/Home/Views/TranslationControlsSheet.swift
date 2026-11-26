import SwiftUI

/// Everything that changes how translation works, without leaving the camera.
struct TranslationControlsSheet: View {
    @State private var viewModel: SettingsViewModel
    private let interface: InterfaceLanguageModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(viewModel: SettingsViewModel, interface: InterfaceLanguageModel) {
        _viewModel = State(initialValue: viewModel)
        self.interface = interface
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.large) {
                    header
                    languages
                    mode
                    speed
                    boxPlace
                    display
                    history
                }
                .padding(AppSpacing.regular)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background { background }
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(Color.appAccent)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(34)
        .presentationBackground(Color.appBackground)
    }

    private var background: some View {
        Color.appBackground
            .overlay(alignment: .top) {
                AppGradient.brand
                    .opacity(0.22)
                    .frame(height: 170)
                    .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
            }
            .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: AppSpacing.medium) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(AppGradient.action, in: .rect(cornerRadius: 14))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(.controlsTitle)
                    .font(.title3.bold())
                    .foregroundStyle(Color.appTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: AppSpacing.small) {
                    Text(verbatim: name(viewModel.settings.source))
                    Image(systemName: "arrow.forward")
                        .font(.caption)
                        .accessibilityHidden(true)
                    Text(verbatim: name(viewModel.settings.target))
                }
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(Color.appTextSecondary)
            }
            Spacer(minLength: 0)
            AppButton(.commonClose, icon: "xmark") { dismiss() }
                .buttonStyle(.icon)
        }
        .padding(.top, AppSpacing.medium)
    }

    private var languages: some View {
        Panel(title: .settingsLanguages) {
            languageMenu(
                .settingsSource, icon: "gamecontroller.fill", tint: .appAccent,
                choices: viewModel.sourceChoices, selection: $viewModel.settings.source
            )
            PanelDivider()
            languageMenu(
                .settingsTarget, icon: "character.bubble.fill", tint: .appSuccess,
                choices: viewModel.targetChoices, selection: $viewModel.settings.target
            )
            PanelDivider()
            NavigationLink {
                LanguagesView(viewModel: viewModel)
            } label: {
                PanelRow(icon: "plus", tint: .appWarning, title: .settingsAddLanguage) {
                    PanelValue(text: nil, style: .link)
                }
            }
            .buttonStyle(.plain)
            PanelDivider()
            NavigationLink {
                InterfaceLanguageView(model: interface)
            } label: {
                PanelRow(icon: "globe", tint: .appPink, title: .interfaceTitle) {
                    PanelValue(text: Text(interface.selection.title), style: .link)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func languageMenu(
        _ title: LocalizedStringResource, icon: String, tint: Color,
        choices: [AppLanguage], selection: Binding<AppLanguage>
    ) -> some View {
        Menu {
            LanguagePicker(title: title, choices: choices, selection: selection)
                .pickerStyle(.inline)
        } label: {
            PanelRow(icon: icon, tint: tint, title: title) {
                PanelValue(text: Text(verbatim: name(selection.wrappedValue)), style: .menu)
            }
        }
        .buttonStyle(.plain)
    }

    private var mode: some View {
        choices(.controlsMode) {
            ChoiceCard(
                icon: "infinity", title: .controlsContinuous, detail: .controlsContinuousDetail,
                isSelected: viewModel.settings.reading.isContinuous
            ) { viewModel.settings.reading.isContinuous = true }
            ChoiceCard(
                icon: "1.circle", title: .controlsOnce, detail: .controlsOnceDetail,
                isSelected: !viewModel.settings.reading.isContinuous
            ) { viewModel.settings.reading.isContinuous = false }
        }
    }

    private var speed: some View {
        choices(.controlsSpeed) {
            ChoiceCard(
                icon: "checkmark.seal", title: .controlsBalanced, detail: .controlsBalancedDetail,
                isSelected: viewModel.settings.reading.speed == .balanced
            ) { viewModel.settings.reading.speed = .balanced }
            ChoiceCard(
                icon: "bolt.fill", title: .controlsFast, detail: .controlsFastDetail,
                isSelected: viewModel.settings.reading.speed == .fast
            ) { viewModel.settings.reading.speed = .fast }
        }
    }

    private func choices(
        _ title: LocalizedStringResource, @ViewBuilder cards: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.appTextSecondary)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, AppSpacing.small)
            HStack(spacing: AppSpacing.medium) { cards() }
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var boxPlace: some View {
        Panel(title: .controlsBox, note: .controlsBoxNote) {
            BoxPresetBar()
                .padding(AppSpacing.medium)
        }
    }

    private var display: some View {
        Panel(title: .controlsDisplay) {
            VStack(alignment: .leading, spacing: AppSpacing.regular) {
                TranslatedTextRow(
                    original: "Follow the car", translation: String(localized: sample),
                    showsOriginal: viewModel.settings.reading.showsOriginal,
                    font: viewModel.settings.reading.textSize.font
                )
                .frame(minHeight: 74, alignment: .leading)
                SegmentedPicker(title: .controlsTextSize, selection: $viewModel.settings.reading.textSize)
            }
            .padding(AppSpacing.regular)
            PanelDivider()
            PanelToggle(icon: "textformat", tint: .appAccent, title: .controlsShowsOriginal, isOn: $viewModel.settings.reading.showsOriginal)
        }
    }

    private var history: some View {
        Panel(title: .historyTitle, note: .controlsSavesHistoryFooter) {
            PanelToggle(icon: "clock.arrow.circlepath", tint: .appSuccess, title: .controlsSavesHistory, isOn: $viewModel.settings.reading.savesHistory)
        }
    }

    /// In the interface language, which may differ from the device's.
    private var sample: LocalizedStringResource {
        var resource = LocalizedStringResource.controlsSample
        resource.locale = locale
        return resource
    }

    private func name(_ language: AppLanguage) -> String { language.displayName(in: locale) }
}

extension ReadingSettings.TextSize: SegmentOption {
    var title: LocalizedStringResource {
        switch self {
        case .small: .controlsTextSmall
        case .medium: .controlsTextMedium
        case .large: .controlsTextLarge
        }
    }
}
