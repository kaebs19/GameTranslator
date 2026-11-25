import SwiftUI

struct LoadingView: View {
    let title: LocalizedStringResource

    var body: some View {
        ProgressView { Text(title) }
            .controlSize(.large)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
