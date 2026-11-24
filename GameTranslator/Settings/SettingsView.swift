import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKey.source, store: AppGroup.defaults) private var source = SourceLanguage.english
    @AppStorage(SettingsKey.target, store: AppGroup.defaults) private var target = TargetLanguage.arabic
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var cacheCleared = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $source) {
                        ForEach(SourceLanguage.allCases) { Text(verbatim: name($0.rawValue)).tag($0) }
                    } label: { Text(.settingsSource) }
                    Picker(selection: $target) {
                        ForEach(TargetLanguage.allCases) { Text(verbatim: name($0.rawValue)).tag($0) }
                    } label: { Text(.settingsTarget) }
                } header: {
                    Text(.settingsLanguages)
                } footer: {
                    Text(.settingsLanguagesFooter)
                }
                Section {
                    Button(role: .destructive, action: clearCache) {
                        Text(cacheCleared ? .settingsCacheCleared : .settingsClearCache)
                    }
                    .disabled(cacheCleared)
                } footer: {
                    Text(.settingsCacheFooter)
                }
            }
            .navigationTitle(Text(.settingsTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text(.commonDone) }
                }
            }
        }
    }

    private func name(_ code: String) -> String { locale.displayName(forLanguage: code) }

    private func clearCache() {
        Task {
            await TranslationCache.shared.clear()
            cacheCleared = true
        }
    }
}
