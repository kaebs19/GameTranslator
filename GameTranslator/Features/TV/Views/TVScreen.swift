import SwiftUI

/// Stand-in until the TV mode is designed.
struct TVScreen: View {
    var body: some View {
        ContentUnavailableView {
            AppLabel(.tvTitle, icon: "tv")
        } description: {
            Text(.tvSoon)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground.ignoresSafeArea())
    }
}
