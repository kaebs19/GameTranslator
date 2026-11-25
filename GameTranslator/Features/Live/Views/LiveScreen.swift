import SwiftUI

struct LiveScreen: View {
    let viewModel: LiveViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsClear = false

    var body: some View {
        NavigationStack {
            content
                .background(Color.appBackground.ignoresSafeArea())
                .navigationTitle(Text(.liveTitle))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
                .confirmationDialog(Text(.liveClearQuestion), isPresented: $confirmsClear, titleVisibility: .visible) {
                    AppButton(.liveClear, role: .destructive) {
                        Task { await viewModel.clear() }
                    }
                }
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            AppButton(.commonClose) { dismiss() }
        }
        if viewModel.isRunning {
            ToolbarItem(placement: .topBarLeading) {
                AppButton(
                    viewModel.isPaused ? .liveResume : .livePause,
                    icon: viewModel.isPaused ? "play.fill" : "pause.fill"
                ) {
                    Task { await viewModel.togglePause() }
                }
            }
        }
        if !viewModel.lines.isEmpty {
            ToolbarItem(placement: .topBarLeading) {
                AppButton(.liveClear, icon: "trash") { confirmsClear = true }
            }
        }
    }

    @ViewBuilder private var content: some View {
        if viewModel.lines.isEmpty {
            LiveIntroView(viewModel: viewModel)
        } else {
            transcript
                .safeAreaInset(edge: .top) { header }
                .bottomActionBar { broadcastControl }
        }
    }

    private var transcript: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.regular) {
                ForEach(viewModel.lines) { line in
                    TranslatedTextRow(original: line.original, translation: line.translation)
                    Divider()
                }
            }
            .padding()
        }
        .defaultScrollAnchor(.bottom)
    }

    private var header: some View {
        VStack(spacing: AppSpacing.small) {
            StatusBadge(title: status, isActive: viewModel.isRunning && !viewModel.isPaused)
            if let error = viewModel.captureError {
                InlineErrorView(error: error)
            }
            if let error = viewModel.translationError {
                InlineErrorView(error: error, retry: viewModel.retryTranslation)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.medium)
        .background(.bar)
    }

    private var status: LocalizedStringResource {
        guard viewModel.isRunning else { return .liveStopped }
        return viewModel.isPaused ? .livePaused : .liveRunning
    }

    private var broadcastControl: some View { LiveStartStopButton(viewModel: viewModel) }
}

/// Explains the broadcast before the first line arrives.
private struct LiveIntroView: View {
    let viewModel: LiveViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                HeroHeader(icon: "dot.radiowaves.left.and.right", message: .liveIntro)
                StepList(steps: [
                    .liveStepStart, .liveStepPlay, viewModel.capturesInApp ? .liveStepWatch : .liveStepReturn
                ])
                if viewModel.isRunning {
                    StatusBadge(title: viewModel.isPaused ? .livePaused : .liveWaiting, isActive: !viewModel.isPaused)
                }
                if let error = viewModel.captureError {
                    InlineErrorView(error: error)
                }
                if let error = viewModel.setupError {
                    InlineErrorView(error: error)
                } else {
                    LiveStartStopButton(viewModel: viewModel)
                }
                Text(viewModel.usesCloud ? .livePrivacyCloud : .livePrivacy)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .controlSize(.large)
            .frame(maxWidth: AppSpacing.maxContentWidth)
            .padding(AppSpacing.large)
            .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.center, for: .alignment)
    }
}

/// In-app capture has its own button; a broadcast can only start from the system's.
private struct LiveStartStopButton: View {
    let viewModel: LiveViewModel

    var body: some View {
        if viewModel.capturesInApp {
            AppButton(
                title, isWide: true, action: viewModel.isRunning ? viewModel.stopCapture : viewModel.startCapture
            )
            .buttonStyle(.primary)
        } else {
            BroadcastButton(title: title)
        }
    }

    private var title: LocalizedStringResource { viewModel.isRunning ? .liveStop : .liveStart }
}
