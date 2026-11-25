import Foundation
import Testing
@testable import GameTranslator

struct LiveTranscriptTests {
    private let session = UUID()

    private func batch(_ lines: [String], at seconds: Double = 0, session: UUID? = nil) -> LiveBatch {
        LiveBatch(
            sessionID: session ?? self.session, sequence: 1,
            date: Date(timeIntervalSince1970: seconds), lines: lines
        )
    }

    private func originals(_ transcript: LiveTranscript) -> [String] { transcript.lines.map(\.original) }

    @Test func scrollingDoesNotRepeatLines() {
        var transcript = LiveTranscript()
        transcript.append(batch(["Alpha opens the gate", "Bravo waits outside"]))
        transcript.append(batch(["Bravo waits outside", "Charlie drives away"], at: 1))
        transcript.append(batch(["Alpha opens the gate", "Bravo waits outside"], at: 2))
        #expect(originals(transcript) == ["Alpha opens the gate", "Bravo waits outside", "Charlie drives away"])
    }

    @Test func typedOutLineIsKeptOnceAndTranslatedAgain() {
        var transcript = LiveTranscript()
        transcript.append(batch(["Get back"], at: 0))
        transcript.apply(["Get back": "ارجع"])
        transcript.append(batch(["Get back to the house"], at: 1))
        #expect(originals(transcript) == ["Get back to the house"])
        #expect(transcript.untranslated == ["Get back to the house"])
    }

    @Test func laterLineWithSameStartIsSeparate() {
        var transcript = LiveTranscript()
        transcript.append(batch(["Get back"], at: 0))
        transcript.append(batch(["Get back to the house"], at: 60))
        #expect(transcript.lines.count == 2)
    }

    @Test func linesShownTogetherAreSeparate() {
        var transcript = LiveTranscript()
        transcript.append(batch(["Options", "Options for controller"]))
        #expect(transcript.lines.count == 2)
    }

    @Test func newBroadcastStartsOver() {
        var transcript = LiveTranscript()
        transcript.append(batch(["Follow the car"]))
        transcript.append(batch(["Follow the car", "Lose the police"], session: UUID()))
        #expect(originals(transcript) == ["Follow the car", "Lose the police"])
    }

    @Test func keepsNewestWithinCapacity() {
        var transcript = LiveTranscript(capacity: 2)
        transcript.append(batch(["First thing", "Second item", "Third object"]))
        #expect(originals(transcript) == ["Second item", "Third object"])
    }
}
