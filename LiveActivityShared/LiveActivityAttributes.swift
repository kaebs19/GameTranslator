import ActivityKit
import Foundation

/// Compiled into both the app and the Live Activity extension.
nonisolated struct LiveActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable, Sendable {
        /// ActivityKit rejects more than 4 KB; this keeps the longest list well below it.
        static let maximumLineLength = 120

        /// Newest last, already translated.
        var lines: [String]
        var pendingCount: Int
        var isPaused: Bool
        /// Translation needs the app in the foreground, for example to download a language.
        var needsApp: Bool
        var updated: Date

        init(lines: [String], pendingCount: Int, isPaused: Bool, needsApp: Bool, updated: Date) {
            self.lines = lines.map { line in
                line.count > Self.maximumLineLength ? line.prefix(Self.maximumLineLength - 1) + "…" : line
            }
            self.pendingCount = pendingCount
            self.isPaused = isPaused
            self.needsApp = needsApp
            self.updated = updated
        }

        func hasSameContent(as other: ContentState) -> Bool {
            var copy = other
            copy.updated = updated
            return self == copy
        }
    }
}

nonisolated enum LiveActivityLink {
    /// Delivered to the app when the activity is tapped.
    static let url = URL(string: "gametranslator://live")!
}
