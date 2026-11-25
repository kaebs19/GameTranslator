import AppIntents
import SwiftUI

/// Lock Screen and banner. iOS gives it at most 160 points of height.
struct LiveActivityLockScreenView: View {
    let state: LiveActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LiveActivityHeader(state: state)
            LiveActivityLines(state: state)
            LiveActivityControls(state: state)
        }
        .padding(12)
    }
}

struct LiveActivityHeader: View {
    let state: LiveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 6) {
            LiveActivityIcon(state: state)
            Text(state.isPaused ? .LiveActivity.activityPaused : .LiveActivity.activityRunning)
            Spacer()
            if state.needsApp {
                Text(.LiveActivity.activityNeedsApp)
                    .foregroundStyle(.orange)
            } else if state.pendingCount > 0 {
                Text(.LiveActivity.activityPending(state.pendingCount))
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

struct LiveActivityIcon: View {
    let state: LiveActivityAttributes.ContentState

    var body: some View {
        Image(systemName: state.isPaused ? "pause.circle" : "text.viewfinder")
            .foregroundStyle(state.isPaused ? Color.orange : Color.accentColor)
    }
}

struct LiveActivityLines: View {
    let state: LiveActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if state.lines.isEmpty {
                Text(.LiveActivity.activityWaiting)
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(state.lines.enumerated()), id: \.offset) { _, line in
                Text(verbatim: line)
                    .fontWeight(.medium)
                    // Two lines of text only fit when few translations are shown.
                    .lineLimit(state.lines.count <= 2 ? 2 : 1)
            }
        }
        .font(state.lines.count <= 3 ? .callout : .caption)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LiveActivityControls: View {
    let state: LiveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 8) {
            // Background translation needs the session type added in iOS 26.
            if #available(iOS 26, *) {
                Button(intent: TranslateLiveIntent()) {
                    Label { Text(.LiveActivity.activityTranslate) } icon: { Image(systemName: "arrow.clockwise") }
                        .frame(maxWidth: .infinity)
                }
                .tint(.accentColor)
            }
            Button(intent: ToggleLivePauseIntent()) {
                Label {
                    Text(state.isPaused ? .LiveActivity.activityResume : .LiveActivity.activityPause)
                } icon: {
                    Image(systemName: state.isPaused ? "play.fill" : "pause.fill")
                }
                .frame(maxWidth: .infinity)
            }
            .tint(.secondary)
            Button(intent: ClearLiveIntent()) {
                Label { Text(.LiveActivity.activityClear) } icon: { Image(systemName: "trash") }
                    .frame(maxWidth: .infinity)
            }
            .tint(.secondary)
        }
        .font(.caption)
        .lineLimit(1)
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
