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
