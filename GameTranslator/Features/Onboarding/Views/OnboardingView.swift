import SwiftUI

/// Explains the modes, and the broadcast in particular, then asks where the user plays.
struct OnboardingView: View {
    /// `nil` when skipped.
    let finish: (PlaySetup?) -> Void
    private let pages = OnboardingPage.all
    @State private var index = 0
    @State private var setup: PlaySetup?

    init(finish: @escaping (PlaySetup?) -> Void) {
        self.finish = finish
    }

    var body: some View {
        VStack(spacing: AppSpacing.regular) {
            TabView(selection: $index) {
                ForEach(pages.indices, id: \.self) { OnboardingPageView(page: pages[$0]).tag($0) }
                SetupPage(selection: $setup).tag(pages.count)
            }
            // The system dots float over the text, which hides it at large sizes.
            .tabViewStyle(.page(indexDisplayMode: .never))
            PageDots(count: pages.count + 1, index: index)
            AppButton(isLast ? .onboardingStart : .onboardingNext, isWide: true, action: advance)
                .buttonStyle(.primary)
                .frame(maxWidth: AppSpacing.maxContentWidth)
                .disabled(isLast && setup == nil)
            AppButton(.onboardingSkip) { finish(nil) }
                .opacity(isLast ? 0 : 1)
                .disabled(isLast)
        }
        .padding()
        .background(Color.appBackground.ignoresSafeArea())
    }

    private var isLast: Bool { index == pages.count }

    private func advance() {
        guard !isLast else { return finish(setup) }
        withAnimation { index += 1 }
    }
}

private struct SetupPage: View {
    @Binding var selection: PlaySetup?

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                HeroHeader(icon: "gamecontroller", message: .setupTitle)
                VStack(spacing: AppSpacing.medium) {
                    ForEach(PlaySetup.allCases) { item in
                        ChoiceCard(icon: item.icon, title: item.title, detail: item.detail, isSelected: selection == item) {
                            selection = item
                        }
                    }
                }
            }
            .frame(maxWidth: AppSpacing.maxContentWidth)
            .padding(AppSpacing.large)
            .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.center, for: .alignment)
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
