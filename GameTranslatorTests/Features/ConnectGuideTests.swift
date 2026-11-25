import Testing
@testable import GameTranslator

@MainActor
struct ConnectGuideTests {
    @Test(arguments: ConnectGuide.allCases)
    func everyWayHasStepsAndEndsSomewhere(guide: ConnectGuide) {
        #expect(guide.steps.count == 3)
        #expect(guide.action == (guide == .screen ? .camera : .broadcast))
    }
}
