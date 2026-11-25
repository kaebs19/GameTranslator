import ActivityKit
import SwiftUI
import WidgetKit

@main
struct LiveActivityBundle: WidgetBundle {
    var body: some Widget {
        LiveTranslationActivity()
    }
}

struct LiveTranslationActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivityAttributes.self) { context in
            LiveActivityLockScreenView(state: context.state)
                .widgetURL(LiveActivityLink.url)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        LiveActivityHeader(state: context.state)
                        LiveActivityLines(state: context.state)
                        LiveActivityControls(state: context.state)
                    }
                }
            } compactLeading: {
                LiveActivityIcon(state: context.state)
            } compactTrailing: {
                if context.state.pendingCount > 0 {
                    Text(context.state.pendingCount, format: .number)
                }
            } minimal: {
                LiveActivityIcon(state: context.state)
            }
            .widgetURL(LiveActivityLink.url)
        }
    }
}
