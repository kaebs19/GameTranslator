import SwiftUI

/// Explains both modes, and the broadcast in particular, before first use.
struct OnboardingView: View {
    let finish: () -> Void
    private let pages = OnboardingPage.all
    @State private var index = 0

    init(finish: @escaping () -> Void) {
        self.finish = finish
    }

    var body: some View {
        VStack(spacing: AppSpacing.regular) {
            TabView(selection: $index) {
                ForEach(pages.indices, id: \.self) { OnboardingPageView(page: pages[$0]).tag($0) }
            }
            // The system dots float over the text, which hides it at large sizes.
            .tabViewStyle(.page(indexDisplayMode: .never))
            PageDots(count: pages.count, index: index)
            AppButton(isLast ? .onboardingStart : .onboardingNext, isWide: true, action: advance)
                .buttonStyle(.primary)
                .frame(maxWidth: AppSpacing.maxContentWidth)
            AppButton(.onboardingSkip, action: finish)
                .opacity(isLast ? 0 : 1)
                .disabled(isLast)
        }
        .padding()
        .background(Color.appBackground.ignoresSafeArea())
    }

    private var isLast: Bool { index == pages.count - 1 }

    private func advance() {
        guard !isLast else { return finish() }
        withAnimation { index += 1 }
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                HeroHeader(icon: page.icon, message: page.title)
                StepList(steps: page.points)
            }
            .frame(maxWidth: AppSpacing.maxContentWidth)
            .padding(AppSpacing.large)
            .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.center, for: .alignment)
    }
}
