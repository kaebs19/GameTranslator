import SwiftUI

/// Tabs, and what may open over the home screen.
struct RootView: View {
    private enum AppTab: Hashable { case home, tv, connect, settings }

    private let dependencies: AppDependencies
    @State private var instant: InstantTranslateViewModel
    @State private var camera: CameraViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection = AppTab.home
    @State private var sheet: HomeSheet?
    @State private var isFullScreen = false
    @State private var showsOnboarding = false
    /// Never in the way of a result someone asked for with a shortcut.
    @State private var showsSplash: Bool
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _instant = State(initialValue: dependencies.makeInstantTranslateViewModel())
        _camera = State(initialValue: dependencies.makeCameraViewModel())
        _showsSplash = State(initialValue: dependencies.router.request == nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            tabs
            if !isFullScreen {
                AppTabBar(items: Self.tabItems, selection: $selection)
                    .transition(.move(edge: .bottom))
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .onChange(of: dependencies.router.request, initial: true) { _, _ in handleRouterRequest() }
        .sheet(item: $sheet, onDismiss: sheetDidClose) { sheet in
            // A navigation bar keeps the direction it was created with, so build a new one.
            sheetContent(sheet)
                .id(language)
                .interfaceLanguage(language)
        }
        .fullScreenCover(isPresented: $showsOnboarding) {
            OnboardingView {
                hasSeenOnboarding = true
                showsOnboarding = false
            }
            .interfaceLanguage(language)
        }
        .overlay {
            if showsSplash { SplashView().transition(.opacity) }
        }
        .interfaceLanguage(language)
        .task { await finishSplash() }
        .onOpenURL { if $0 == LiveActivityLink.url { dependencies.router.open(.live) } }
        .translationHost(dependencies.translationService)
        .task { live.startObserving() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { live.appDidBecomeActive() }
        }
    }

    private var language: InterfaceLanguage { dependencies.interface.selection }

    private static let tabItems: [AppTabBar<AppTab>.Item] = [
        .init(tab: .home, title: .homeTab, icon: "house.fill"),
        .init(tab: .tv, title: .tvTitle, icon: "tv.fill"),
        .init(tab: .connect, title: .connectTitle, icon: "link"),
        .init(tab: .settings, title: .settingsTitle, icon: "gearshape.fill")
    ]

    /// Keeps each tab alive; the bar itself is ours.
    private var tabs: some View {
        TabView(selection: $selection) {
            Tab(value: AppTab.home) {
                HomeScreen(
                    camera: camera, isActive: selection == .home && !isCovered,
                    isFullScreen: $isFullScreen,
                    open: { sheet = $0 },
                    useLatestScreenshot: { translate(.latestScreenshot) },
                    translatePhoto: translatePhoto
                )
                .toolbar(.hidden, for: .tabBar)
            }
            Tab(value: AppTab.tv) {
                TVScreen()
                    .toolbar(.hidden, for: .tabBar)
            }
            Tab(value: AppTab.connect) {
                ConnectScreen(isBroadcasting: live.isRunning, perform: connect)
                    .id(language)
                    .toolbar(.hidden, for: .tabBar)
            }
            Tab(value: AppTab.settings) {
                SettingsScreen(
                    viewModel: dependencies.makeSettingsViewModel(),
                    makeCloudViewModel: dependencies.makeCloudSettingsViewModel,
                    interface: dependencies.interface,
                    showOnboarding: { showsOnboarding = true }
                )
                .id(language)
                .toolbar(.hidden, for: .tabBar)
            }
        }
        .onChange(of: selection) { old, _ in
            if old == .settings { settingsDidChange() }
        }
    }

    @ViewBuilder private func sheetContent(_ sheet: HomeSheet) -> some View {
        switch sheet {
        case .image:
            InstantTranslateScreen(
                viewModel: instant, makeResultViewModel: dependencies.makeTranslationResultViewModel
            )
        case .live:
            LiveScreen(viewModel: live)
        case .history:
            HistoryScreen(viewModel: dependencies.makeHistoryViewModel())
        case .controls:
            TranslationControlsSheet(
                viewModel: dependencies.makeSettingsViewModel(), interface: dependencies.interface
            )
        }
    }

    private var live: LiveViewModel { dependencies.liveViewModel }

    /// The camera must not run behind something that hides it.
    private var isCovered: Bool { sheet != nil || showsOnboarding || showsSplash }

    private func sheetDidClose() {
        // Not when another sheet, perhaps a new image, took its place.
        if sheet == nil { instant.reset() }
        settingsDidChange()
    }

    private func settingsDidChange() {
        camera.settingsDidChange()
        live.settingsDidClose()
    }

    private func connect(_ action: ConnectGuide.Action) {
        switch action {
        case .broadcast: sheet = .live
        case .camera: selection = .home
        }
    }

    private func translate(_ request: AppRouter.Request) {
        instant.handle(request)
        sheet = .image
    }

    private func translatePhoto(_ loadData: @escaping () async throws -> Data?) {
        instant.translate(loadData)
        sheet = .image
    }

    // MARK: Launch

    private func finishSplash() async {
        if showsSplash {
            try? await Task.sleep(for: SplashView.duration)
            hideSplash()
        }
        showFirstOnboarding()
    }

    private func hideSplash() {
        withAnimation(.easeOut(duration: 0.3)) { showsSplash = false }
    }

    private func showFirstOnboarding() {
        guard !hasSeenOnboarding, dependencies.router.request == nil, sheet == nil else { return }
        showsOnboarding = true
    }

    private func handleRouterRequest() {
        guard let request = dependencies.router.takeRequest() else { return }
        hideSplash()
        isFullScreen = false
        selection = .home
        switch request {
        case .live: sheet = .live
        case .latestScreenshot, .image: translate(request)
        }
    }
}
