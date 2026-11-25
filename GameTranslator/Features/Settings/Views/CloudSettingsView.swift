import SwiftUI

struct CloudSettingsView: View {
    @State private var viewModel: CloudSettingsViewModel
    @State private var asksConsent = false
    /// The parent keeps its own copy of the settings.
    private let onChange: () -> Void

    init(viewModel: CloudSettingsViewModel, onChange: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onChange = onChange
    }

    var body: some View {
        Form {
            Group {
                Section {
                    Text(.cloudExplanation)
                }
                if viewModel.isEnabled { enabledSection } else { keySection }
            }
            .listRowBackground(Color.appSurface)
        }
        .navigationTitle(Text(.cloudTitle))
        .navigationBarTitleDisplayMode(.inline)
        .appScreenBackground()
        .errorAlert($viewModel.error)
        .confirmationDialog(Text(.cloudConsentTitle), isPresented: $asksConsent, titleVisibility: .visible) {
            AppButton(.cloudConsentAgree, action: enable)
        } message: {
            Text(.cloudConsentMessage)
        }
    }

    private var enabledSection: some View {
        Section {
            AppLabel(.cloudEnabled, icon: "checkmark.circle.fill")
                .foregroundStyle(.green)
            AppButton(.cloudDisable, role: .destructive) {
                viewModel.disable()
                onChange()
            }
        } footer: {
            Text(.cloudDisableFooter)
        }
    }

    private var keySection: some View {
        Section {
            SecureField(text: $viewModel.enteredKey) { Text(.cloudKey) }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .environment(\.layoutDirection, .leftToRight)
            HStack {
                AppButton(.cloudEnable) { asksConsent = true }
                    .disabled(!viewModel.canEnable)
                if viewModel.isChecking {
                    Spacer()
                    ProgressView()
                }
            }
        } footer: {
            Text(.cloudKeyFooter)
        }
    }

    private func enable() {
        Task {
            await viewModel.enable()
            onChange()
        }
    }
}
