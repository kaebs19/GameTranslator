import SwiftUI

/// Row of large actions pinned to the bottom of a screen.
struct BottomActionBar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: AppSpacing.medium) { content }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding()
            .background(.bar)
    }
}

extension View {
    func bottomActionBar(@ViewBuilder _ content: () -> some View) -> some View {
        let bar = BottomActionBar(content: content)
        return safeAreaInset(edge: .bottom) { bar }
    }
}
