import SwiftUI

struct SettingsScreen: View {
    @State private var viewModel: SettingsViewModel
    private let makeCloudViewModel: () -> CloudSettingsViewModel
    private let interface: InterfaceLanguageModel
    private let showOnboarding: () -> Void

    init(
        viewModel: SettingsViewModel, makeCloudViewModel: @escaping () -> CloudSettingsViewModel,
        interface: InterfaceLanguageModel, showOnboarding: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.makeCloudViewModel = makeCloudViewModel
        self.interface = interface
        self.showOnboarding = showOnboarding
    }

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    languagesSection
                    boxSection
                    liveSection
                    if viewModel.supportsScreenCapture { captureSection }
                    serverSection
                    cloudSection
                    cacheSection
                    aboutSection
                }
                .listRowBackground(Color.appSurface)
            }
            .navigationTitle(Text(.settingsTitle))
            .navigationBarTitleDisplayMode(.inline)
            .errorAlert($viewModel.error)
            .appScreenBackground()
        }
        // The camera's controls change the same settings.
        .onAppear(perform: viewModel.reload)
    }

    private var languagesSection: some View {
        Section {
            LanguagePicker(
                title: .settingsSource, choices: viewModel.sourceChoices, selection: $viewModel.settings.source
            )
            LanguagePicker(
                title: .settingsTarget, choices: viewModel.targetChoices, selection: $viewModel.settings.target
            )
            NavigationLink {
                LanguagesView(viewModel: viewModel)
            } label: {
                AppLabel(.settingsAddLanguage, icon: "plus")
            }
            NavigationLink {
                InterfaceLanguageView(model: interface)
            } label: {
                LabeledContent {
                    Text(interface.selection.title)
                } label: {
                    AppLabel(.interfaceTitle, icon: "globe")
                }
            }
        } header: {
            Text(.settingsLanguages)
        } footer: {
            Text(.settingsLanguagesFooter)
        }
    }

    private var boxSection: some View {
        Section {
            BoxPresetBar()
        } header: {
            Text(.controlsBox)
        } footer: {
            Text(.controlsBoxNote)
        }
    }

    private var serverSection: some View {
        Section {
            Toggle(isOn: $viewModel.settings.server.isEnabled) { Text(.serverToggle) }
            if viewModel.settings.server.isEnabled {
                Picker(selection: $viewModel.settings.server.style) {
                    Text(.serverStyleStandard).tag(ServerSettings.Style.standard)
                    Text(.serverStyleGulf).tag(ServerSettings.Style.gulf)
                } label: {
                    Text(.serverStyle)
                }
            }
        } header: {
            Text(.serverTitle)
        } footer: {
            Text(.serverFooter)
        }
    }

    private var cloudSection: some View {
        Section {
            NavigationLink {
                CloudSettingsView(viewModel: makeCloudViewModel(), onChange: viewModel.reload)
            } label: {
                LabeledContent {
                    Text(viewModel.settings.usesCloudTranslation ? .commonOn : .commonOff)
                } label: {
                    Text(.cloudTitle)
                }
            }
        } footer: {
            Text(.settingsCloudFooter)
        }
    }

    private var aboutSection: some View {
        Section {
            NavigationLink {
                PrivacyPolicyView()
            } label: {
                AppLabel(.privacyTitle, icon: "hand.raised")
            }
            AppButton(.settingsShowOnboarding, icon: "questionmark.circle") {
                showOnboarding()
            }
        }
    }

    private var liveSection: some View {
        Section {
            Toggle(isOn: $viewModel.settings.live.showsLiveActivity) { Text(.settingsLiveActivity) }
            Toggle(isOn: notificationsBinding) { Text(.settingsNotifications) }
            Stepper(value: $viewModel.settings.live.lineCount, in: LiveSettings.lineCountRange) {
                Text(.settingsLineCount(viewModel.settings.live.lineCount))
            }
        } header: {
            Text(.settingsLive)
        } footer: {
            Text(.settingsLiveFooter)
        }
    }

    private var captureSection: some View {
        Section {
            Toggle(isOn: $viewModel.settings.live.usesScreenCapture) { Text(.settingsScreenCapture) }
        } footer: {
            Text(.settingsScreenCaptureFooter)
        }
    }

    private var notificationsBinding: Binding<Bool> {
        Binding {
            viewModel.settings.live.sendsNotifications
        } set: { isOn in
            Task { await viewModel.setNotifications(isOn) }
        }
    }

    private var cacheSection: some View {
        Section {
            AppButton(viewModel.isCacheCleared ? .settingsCacheCleared : .settingsClearCache, role: .destructive) {
                Task { await viewModel.clearCache() }
            }
            .disabled(viewModel.isCacheCleared)
        } footer: {
            Text(.settingsCacheFooter)
        }
    }
}
