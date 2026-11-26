import PhotosUI
import SwiftUI

/// The camera, with everything else around its edges.
struct HomeScreen: View {
    let camera: CameraViewModel
    /// False while something covers the camera.
    let isActive: Bool
    @Binding var isFullScreen: Bool
    let open: (HomeSheet) -> Void
    let useLatestScreenshot: () -> Void
    let translatePhoto: (@escaping () async throws -> Data?) -> Void
    @State private var pickedItem: PhotosPickerItem?
    @AppStorage("scanBox") private var box = ScanBox.standard
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// Two lines of translation with their original, at any text size.
    @ScaledMetric(relativeTo: .title3) private var panelHeight: CGFloat = 150

    private static let maximumPanelHeight: CGFloat = 230

    var body: some View {
        layout
            .background(Color.appBackground.ignoresSafeArea())
            .statusBarHidden(isFullScreen)
            .persistentSystemOverlays(isFullScreen ? .hidden : .automatic)
            // The camera only runs while it is really on screen.
            .task(id: shouldRun) {
                if shouldRun { await camera.start() } else { camera.stop() }
            }
            .onDisappear(perform: camera.stop)
            .onChange(of: pickedItem) { _, item in
                guard let item else { return }
                pickedItem = nil
                translatePhoto { try await item.loadTransferable(type: Data.self) }
            }
    }

    private var shouldRun: Bool { isActive && scenePhase == .active }

    @ViewBuilder private var layout: some View {
        if isFullScreen {
            viewport
                .overlay(alignment: .bottom) {
                    PlayButton(viewModel: camera)
                        .padding(AppSpacing.medium)
                }
                .background(Color.black.ignoresSafeArea())
        } else if verticalSizeClass == .compact {
            HStack(spacing: AppSpacing.medium) {
                viewport
                VStack(spacing: AppSpacing.medium) {
                    topBar
                    TranslationPanel(viewModel: camera)
                    HomeControls(viewModel: camera)
                }
                .frame(width: 330)
            }
            .padding(AppSpacing.medium)
        } else {
            VStack(spacing: AppSpacing.medium) {
                topBar
                viewport
                TranslationPanel(viewModel: camera)
                    .frame(height: min(panelHeight, Self.maximumPanelHeight))
                HomeControls(viewModel: camera)
            }
            .padding(.horizontal, AppSpacing.medium)
            .padding(.vertical, AppSpacing.small * 2)
        }
    }

    private var topBar: some View {
        HomeTopBar(
            viewModel: camera, pickedItem: $pickedItem, useLatestScreenshot: useLatestScreenshot, open: open
        )
    }

    @ViewBuilder private var viewport: some View {
        if case .failed(let error) = camera.state {
            ErrorStateView(error: error, dismissTitle: .errorRetry) {
                Task { await camera.retry() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .card()
            .onAppear { isFullScreen = false }
        } else {
            CameraViewport(
                viewModel: camera, box: $box, isFullScreen: $isFullScreen,
                showsTranslation: isFullScreen
            )
        }
    }
}
