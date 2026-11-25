import SwiftUI

/// Language name with its native spelling and an optional note.
struct LanguageRow: View {
    let language: AppLanguage
    var note: LocalizedStringResource?
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(verbatim: language.displayName(in: locale))
                .foregroundStyle(.primary)
            HStack(spacing: AppSpacing.medium) {
                Text(verbatim: language.nativeName)
                if let note { Text(note) }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
