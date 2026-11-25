import SwiftUI

/// Picker over a list of languages, named in the user's language.
struct LanguagePicker: View {
    let title: LocalizedStringResource
    let choices: [AppLanguage]
    @Binding var selection: AppLanguage
    @Environment(\.locale) private var locale

    var body: some View {
        Picker(selection: $selection) {
            ForEach(choices) { Text(verbatim: $0.displayName(in: locale)).tag($0) }
        } label: {
            Text(title)
        }
    }
}
