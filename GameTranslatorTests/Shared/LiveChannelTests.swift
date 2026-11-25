import Foundation
import Testing
@testable import GameTranslator

struct LiveChannelTests {
    private let directory = FileManager.default.temporaryDirectory.appending(path: "live-\(UUID().uuidString)")
    private let session = UUID()

    private func batch(_ sequence: Int, _ lines: [String] = ["x"]) -> LiveBatch {
        LiveBatch(
            sessionID: session, sequence: sequence,
            date: Date(timeIntervalSince1970: 1_000 + Double(sequence / 3)), lines: lines
        )
    }

    @Test func deliversInOrderExactlyOnceAndLeavesNoText() throws {
        let channel = LiveChannel(directory: directory)
        for sequence in 1...12 { try channel.send(batch(sequence)) }
        #expect(channel.drain().map(\.sequence) == Array(1...12))
        #expect(channel.drain().isEmpty)
        let left = try FileManager.default.contentsOfDirectory(atPath: directory.appending(path: "Inbox").path)
        #expect(left.isEmpty)
    }

    @Test func dropsOldestBeyondLimit() throws {
        let channel = LiveChannel(directory: directory, maxPending: 3)
        for sequence in 1...5 { try channel.send(batch(sequence)) }
        #expect(channel.drain().map(\.sequence) == [3, 4, 5])
    }

    @Test func skipsDamagedFiles() throws {
        let channel = LiveChannel(directory: directory)
        try channel.send(batch(1))
        try Data("broken".utf8).write(to: directory.appending(path: "Inbox/000-bad.json"))
        #expect(channel.drain().map(\.sequence) == [1])
    }

    @Test func emptyChannelIsQuiet() {
        let channel = LiveChannel(directory: directory)
        #expect(channel.drain().isEmpty)
        #expect(channel.status() == nil)
        channel.removeAllBatches()
    }

    @Test func statusGoesStaleWithoutHeartbeat() throws {
        let channel = LiveChannel(directory: directory)
        let now = Date(timeIntervalSince1970: 5_000)
        try channel.write(LiveStatus(sessionID: session, isRunning: true, heartbeat: now))
        let status = try #require(channel.status())
        #expect(status.isActive(at: now.addingTimeInterval(LiveStatus.heartbeatInterval)))
        #expect(!status.isActive(at: now.addingTimeInterval(LiveStatus.staleAfter)))
        #expect(!LiveStatus(sessionID: session, isRunning: false, heartbeat: now).isActive(at: now))
    }

    @Test func darwinNotificationReachesObserver() async throws {
        let name = "test.\(UUID().uuidString)"
        let stream = DarwinNotification.stream(name)
        let poster = Task {
            while !Task.isCancelled {
                DarwinNotification.post(name)
                try await Task.sleep(for: .milliseconds(50))
            }
        }
        defer { poster.cancel() }
        var received = false
        for await _ in stream {
            received = true
            break
        }
        #expect(received)
    }

    @Test func controlRoundTripsAndDefaultsToRunning() throws {
        let channel = LiveChannel(directory: directory)
        #expect(channel.control() == LiveControl(isPaused: false, generation: 0))
        try channel.write(LiveControl(isPaused: true, generation: 3))
        #expect(channel.control() == LiveControl(isPaused: true, generation: 3))
    }

    @MainActor
    @Test func feedControlsTheExtension() throws {
        let channel = LiveChannel(directory: directory)
        try channel.send(batch(1))
        let feed = AppGroupLiveFeed(channel: channel)
        feed.setPaused(true)
        feed.clear()
        #expect(channel.control() == LiveControl(isPaused: true, generation: 1))
        #expect(feed.drain().isEmpty)
    }

    @Test func notificationsAreThrottled() {
        var throttle = NotificationThrottle(interval: 30)
        let allowed = [0.0, 1, 29, 30, 45, 61].filter { throttle.allows(at: $0) }
        #expect(allowed == [0, 30, 61])
    }
}
