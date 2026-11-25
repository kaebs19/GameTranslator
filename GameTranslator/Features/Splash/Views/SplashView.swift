import SwiftUI

/// Continues the system launch screen: same color, same logo, same place, then the name fades in.
struct SplashView: View {
    /// Short on purpose: the app is ready underneath.
    static let duration = Duration.milliseconds(900)

    @State private var showsName = false

    var body: some View {
        ZStack {
            Color(.launchBackground)
            Image(.launchLogo)
                .accessibilityHidden(true)
                // An overlay, so the name never moves the logo off the launch screen's center.
                .overlay(alignment: .bottom) { name }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) { showsName = true }
        }
    }

    private var name: some View {
        Text(.appName)
            .font(.title.bold())
            .foregroundStyle(.white)
            .fixedSize()
            .alignmentGuide(.bottom) { _ in -AppSpacing.large }
            .opacity(showsName ? 1 : 0)
    }
}
