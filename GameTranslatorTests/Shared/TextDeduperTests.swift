import Testing
@testable import GameTranslator

struct TextDeduperTests {
    @Test func keepsOrderAndReturnsOnlyNewLines() {
        var deduper = TextDeduper()
        #expect(deduper.merge(["Press X to enter", "Follow the car"]) == ["Press X to enter", "Follow the car"])
        #expect(deduper.merge(["Follow the car", "Lose the police"]) == ["Lose the police"])
        #expect(deduper.transcript == ["Press X to enter", "Follow the car", "Lose the police"])
    }

    @Test func dropsDuplicatesInsideOneBatch() {
        var deduper = TextDeduper()
        #expect(deduper.merge(["Hello there", "Hello there"]) == ["Hello there"])
    }

    @Test(arguments: ["  follow   the car ", "FOLLOW THE CAR", "Follow the car!", "Follow\nthe car", "Fóllow the car"])
    func ignoresCaseSpacingPunctuationAndAccents(variant: String) {
        var deduper = TextDeduper()
        deduper.merge(["Follow the car"])
        #expect(deduper.merge([variant]).isEmpty)
    }

    @Test(arguments: ["Get back to the safehovse", "Get back to the safehous", "Get bock to the safehouse"])
    func ignoresSmallRecognitionErrors(variant: String) {
        var deduper = TextDeduper()
        deduper.merge(["Get back to the safehouse"])
        #expect(deduper.merge([variant]).isEmpty)
    }

    @Test func keepsShortLinesThatDifferByOneLetter() {
        var deduper = TextDeduper()
        #expect(deduper.merge(["Cat", "Car", "Yes", "Yep"]).count == 4)
    }

    @Test func keepsLinesThatDifferOnlyByNumber() {
        var deduper = TextDeduper()
        #expect(deduper.merge(["Complete mission number 1", "Complete mission number 2"]).count == 2)
    }

    @Test(arguments: [
        ("Go to the north gate", "Go to the south gate"),
        ("Kill all of the red guards now", "Kill all of the old guards now"),
        ("alpha bravo charlie near the delta gate", "alpha bravo kilo near the delta gate")
    ])
    func keepsLinesThatDifferByOneWord(first: String, second: String) {
        var deduper = TextDeduper()
        #expect(deduper.merge([first, second]).count == 2)
    }

    @Test func ignoresMissingSpaces() {
        var deduper = TextDeduper()
        deduper.merge(["Get back to the safehouse"])
        #expect(deduper.merge(["Getback to thesafehouse"]).isEmpty)
    }

    @Test func keepsDifferentSentences() {
        var deduper = TextDeduper()
        #expect(deduper.merge(["Go to the red house", "Go to the old garage"]).count == 2)
    }

    @Test func skipsEmptyAndSymbolOnlyLines() {
        var deduper = TextDeduper()
        #expect(deduper.merge(["", "   ", "---", "•"]).isEmpty)
    }

    @Test func mergesOverlappingScrollWindowsWithoutRepeats() {
        let script = ["Alpha opens the gate", "Bravo waits outside", "Charlie drives away", "Delta calls for help", "Echo hides the cash"]
        var deduper = TextDeduper()
        for start in 0...2 { deduper.merge(Array(script[start..<start + 3])) }
        for start in (0...2).reversed() { deduper.merge(Array(script[start..<start + 3])) }
        #expect(deduper.transcript == script)
    }

    @Test func storesCleanedText() {
        var deduper = TextDeduper()
        #expect(deduper.merge(["  Hello \n World  "]) == ["Hello World"])
    }

    @Test func forgetsOldestBeyondCapacity() {
        var deduper = TextDeduper(capacity: 2)
        deduper.merge(["First thing", "Second item", "Third object"])
        #expect(deduper.transcript == ["Second item", "Third object"])
        #expect(!deduper.contains("First thing"))
    }

    @Test func resetForgetsEverything() {
        var deduper = TextDeduper()
        deduper.merge(["Follow the car"])
        deduper.reset()
        #expect(deduper.transcript.isEmpty)
        #expect(deduper.merge(["Follow the car"]).count == 1)
    }

    @Test func thresholdOfOneMeansExactOnly() {
        var deduper = TextDeduper(similarityThreshold: 1)
        #expect(deduper.merge(["Get back to the safehouse", "Get back to the safehovse"]).count == 2)
    }
}

struct EditDistanceTests {
    @Test func comparesAgainstLimit() {
        #expect(EditDistance.isWithin(3, Array("kitten"), Array("sitting")))
        #expect(!EditDistance.isWithin(2, Array("kitten"), Array("sitting")))
        #expect(EditDistance.isWithin(0, Array("same"), Array("same")))
        #expect(EditDistance.isWithin(2, [], Array("ab")))
        #expect(!EditDistance.isWithin(1, [], Array("ab")))
    }
}

struct TextNormalizerTests {
    @Test func translatableNeedsALetter() {
        #expect(TextNormalizer.isTranslatable("Level 3"))
        #expect(!TextNormalizer.isTranslatable("12:30"))
        #expect(!TextNormalizer.isTranslatable("$1,250"))
    }
}
