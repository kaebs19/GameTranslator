import SwiftUI

struct InterfaceLanguageView: View {
    @Bindable var model: InterfaceLanguageModel

    var body: some View {
        List {
            Section {
                ForEach(InterfaceLanguage.allCases, id: \.self) { language in
                    Button { model.selection = language } label: {
                        HStack {
                            Text(language.title)
                                .foregroundStyle(Color.appTextPrimary)
                            Spacer()
                            if language == model.selection {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.appAccent)
                            }
                        }
                        .contentShape(.rect)
                    }
                    .accessibilityAddTraits(language == model.selection ? .isSelected : [])
                }
            } footer: {
                Text(.interfaceFooter)
            }
            .listRowBackground(Color.appSurface)
        }
        .appScreenBackground()
        .navigationTitle(Text(.interfaceTitle))
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension InterfaceLanguage {
    /// The two languages are named in their own words, so anyone can find theirs.
    var title: LocalizedStringResource {
        switch self {
        case .system: .interfaceSystem
        case .arabic: .interfaceArabic
        case .english: .interfaceEnglish
        }
    }
}
