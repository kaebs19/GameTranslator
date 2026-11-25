import SwiftUI

/// Add languages the device supports, or remove ones that are not needed.
struct LanguagesView: View {
    let viewModel: SettingsViewModel
    @State private var query = ""
    @Environment(\.locale) private var locale

    var body: some View {
        List {
            Group {
                addedSection
                availableSection
            }
            .listRowBackground(Color.appSurface)
        }
        .navigationTitle(Text(.languagesTitle))
        .navigationBarTitleDisplayMode(.inline)
        .appScreenBackground()
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text(.languagesSearch))
        .task { await viewModel.loadCatalog() }
        .animation(.default, value: viewModel.settings.languages)
    }

    private var addedSection: some View {
        Section {
            ForEach(viewModel.addedLanguages(matching: query, locale: locale)) { language in
                row(language, icon: "minus.circle.fill", color: .red, label: .languagesRemove) {
                    viewModel.remove(language)
                }
                .disabled(!viewModel.settings.canRemove(language))
            }
        } header: {
            Text(.languagesAdded)
        } footer: {
            Text(.languagesAddedFooter)
        }
    }

    private var availableSection: some View {
        Section {
            if viewModel.catalogLanguages == nil {
                ProgressView()
            } else if viewModel.catalogLanguages?.isEmpty == true {
                Text(.languagesUnavailable).foregroundStyle(.secondary)
            }
            ForEach(viewModel.availableLanguages(matching: query, locale: locale)) { language in
                row(language, icon: "plus.circle.fill", color: .green, label: .languagesAdd) {
                    viewModel.add(language)
                }
            }
        } header: {
            Text(.languagesAvailable)
        } footer: {
            Text(.languagesAvailableFooter)
        }
    }

    private func row(
        _ language: AppLanguage, icon: String, color: Color, label: LocalizedStringResource,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            LanguageRow(language: language, note: viewModel.canRead(language) ? nil : .languagesTargetOnly)
            Spacer()
            AppButton(label, icon: icon, action: action)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .tint(color)
                .imageScale(.large)
                .accessibilityHint(Text(verbatim: language.displayName(in: locale)))
        }
    }
}
