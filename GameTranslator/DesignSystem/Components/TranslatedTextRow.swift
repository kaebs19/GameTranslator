import SwiftUI

/// Translation with its original underneath. Falls back to the original when untranslated.
struct TranslatedTextRow: View {
    let original: String
    let translation: String?
    var showsOriginal = true
    var font = Font.headline

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(verbatim: translation ?? original)
                .font(font)
                .foregroundStyle(translation == nil ? Color.appTextSecondary : Color.appTextPrimary)
            if showsOriginal, translation != nil {
                Text(verbatim: original)
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }
}
