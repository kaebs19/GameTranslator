import CoreGraphics
import ImageIO
import Testing
@testable import GameTranslator

@MainActor
struct TVRelayTests {
    private final class Sent: @unchecked Sendable {
        var pictures: [[String]] = []
    }

    private func relay(_ sent: Sent) -> TVRelay {
        TVRelay(recognize: { _, _, _ in [] }, send: { texts in sent.pictures.append(texts) })
    }

    @Test func sendsOnlyWhenTheSubtitleChanges() async throws {
        let sent = Sent()
        let relay = relay(sent)
        #expect(relay.update(["Follow the car to the docks"]) == ["Follow the car to the docks"])
        try await Task.sleep(for: .milliseconds(50))
        // The same line read again, with a small mistake.
        #expect(relay.update(["Follow the car to the dock"]).isEmpty)
        #expect(relay.update(["Lose the police"]) == ["Lose the police"])
        try await Task.sleep(for: .milliseconds(50))
        #expect(sent.pictures == [["Follow the car to the docks"], ["Lose the police"]])
    }

    @Test func clearsTheTVOnceTheSubtitleIsGone() async throws {
        let sent = Sent()
        let relay = relay(sent)
        relay.update(["Follow the car"])
        try await Task.sleep(for: .milliseconds(50))
        for _ in 0..<TVRelay.emptyReadingsToClear + 2 { relay.update([]) }
        try await Task.sleep(for: .milliseconds(50))
        #expect(sent.pictures == [["Follow the car"], []])
    }

    @Test(arguments: [
        (CGImagePropertyOrientation.up, CGRect(x: 0.1, y: 0.7, width: 0.8, height: 0.2)),
        (.right, CGRect(x: 0.7, y: 0.1, width: 0.2, height: 0.8)),
        (.left, CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.8)),
        (.down, CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.2)),
    ])
    func mapsTheBoxToTurnedFrames(orientation: CGImagePropertyOrientation, expected: CGRect) {
        let rect = TVRelay.bufferRect(for: CGRect(x: 0.1, y: 0.7, width: 0.8, height: 0.2), orientation: orientation)
        #expect(abs(rect.minX - expected.minX) < 0.0001 && abs(rect.minY - expected.minY) < 0.0001)
        #expect(abs(rect.width - expected.width) < 0.0001 && abs(rect.height - expected.height) < 0.0001)
    }

    @Test func boxStaysUsable() {
        let rect = RemotePlaySettings.clamped(CGRect(x: 0.95, y: -0.2, width: 0.01, height: 2))
        #expect(rect.width == 0.1 && rect.height == 1 && rect.maxX <= 1 && rect.minY == 0)
    }
}
