import CoreGraphics
import Testing
@testable import GameTranslator

@MainActor
struct TVGuideTests {
    @Test func startsByChoosingTheTV() {
        var guide = TVGuide()
        #expect(guide.step == .choose && !guide.canContinue(isConnected: false))
        guide.choose(.android)
        #expect(guide.step == .install && guide.number == 2 && guide.count == 7)
    }

    @Test func waitsForTheTVBeforeLeavingThePairingStep() {
        var guide = TVGuide(kind: .android)
        while guide.step != .pair { guide.next() }
        #expect(!guide.canContinue(isConnected: false))
        #expect(guide.canContinue(isConnected: true))
        guide.next()
        #expect(guide.step == .test)
        guide.next()
        #expect(guide.step == .done && guide.isLast)
        guide.next()
        #expect(guide.step == .done)
    }

    @Test func browserShowsTheAddressAndThenTheCode() {
        let guide = TVGuide(kind: .browser)
        #expect(guide.steps == [.choose, .address, .browserPair, .test, .done])
        #expect(guide.step == .address)
    }

    @Test func unavailableTVsCanSwitchToTheBrowser() {
        var guide = TVGuide(kind: .samsung)
        #expect(guide.step == .unavailable && guide.isLast)
        guide.choose(.browser)
        #expect(guide.step == .address)
        guide.back()
        #expect(guide.step == .choose && !guide.canGoBack)
    }
}

@MainActor
struct DeviceReadinessTests {
    @Test func tvNeedsAttentionWhenPairedButNotConnected() {
        #expect(DeviceReadiness().tv == .off)
        #expect(DeviceReadiness(pairedTVs: 1, connectedTVs: 0).tv == .attention)
        #expect(DeviceReadiness(pairedTVs: 2, connectedTVs: 1).tv == .ready)
    }

    @Test func enhancedTranslationFollowsTheSetting() {
        #expect(DeviceReadiness().enhanced == .off)
        #expect(DeviceReadiness(usesEnhancedTranslation: true).enhanced == .ready)
    }
}

private final class StubLinks: ServerTVLinking, @unchecked Sendable {
    var list: [ServerTV] = []
    func newTVCode() async throws -> String { "9123456" }
    func tvs() async throws -> [ServerTV] { list }
    func removeTV(_ id: String) async throws {}
}

@MainActor
struct RemotePlayGuideTests {
    private let links = StubLinks()
    private let settings = InMemorySettingsStore()
    private final class Live { var lines = 0; var running = false }
    private let live = Live()

    private func model() -> RemotePlayGuideViewModel {
        RemotePlayGuideViewModel(
            links: links, settings: settings, lineCount: { [live] in live.lines }, isBroadcasting: { [live] in live.running }
        )
    }

    @Test func eachStepWaitsUntilItIsDone() async throws {
        let guide = model()
        #expect(guide.step == .console && !guide.canContinue)
        guide.next()
        #expect(guide.step == .console)
        guide.confirm()
        guide.next()
        guide.confirm()
        guide.next()
        guide.confirm()
        guide.next()
        #expect(guide.step == .pair && !guide.canContinue)
        links.list = [ServerTV(id: "a", name: "TV", isConnected: true)]
        #expect(try await eventually { guide.canContinue })
        #expect(guide.code == "9123456")
        guide.next()
        #expect(guide.step == .region)
        guide.setRegionPreset(CGRect(x: 0.1, y: 0.06, width: 0.8, height: 0.22))
        guide.confirm()
        #expect(settings.load().remotePlay.region.minY == 0.06)
        guide.next()
        #expect(guide.step == .broadcast && settings.load().remotePlay.sendsToTV && !guide.canContinue)
        live.running = true
        #expect(try await eventually { guide.canContinue })
        live.lines = 4
        guide.next()
        #expect(guide.step == .play && !guide.canContinue)
        live.lines = 5
        #expect(try await eventually { guide.canContinue })
        guide.next()
        #expect(guide.isLast)
        guide.stop()
    }
}
