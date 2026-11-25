import SwiftUI

/// Localized title with an SF Symbol. `isWide` fills the available width, for full-size buttons.
struct AppLabel: View {
    let title: LocalizedStringResource
    let icon: String
    let isWide: Bool

    /// Nonisolated because PhotosPicker builds its label outside the main actor.
    nonisolated init(_ title: LocalizedStringResource, icon: String, isWide: Bool = false) {
        self.title = title
        self.icon = icon
        self.isWide = isWide
    }

    var body: some View {
        Label { Text(title) } icon: { Image(systemName: icon) }
            .frame(maxWidth: isWide ? .infinity : nil)
    }
}
