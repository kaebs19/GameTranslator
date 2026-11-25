import CoreGraphics
import Testing
@testable import GameTranslator

@MainActor
struct ScanBoxTests {
    private let size = CGSize(width: 400, height: 800)
    private let box = ScanBox(rect: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.25))

    private func expect(_ box: ScanBox, _ x: Double, _ y: Double, _ width: Double, _ height: Double) {
        let values = [box.rect.minX, box.rect.minY, box.rect.width, box.rect.height]
        #expect(zip(values, [x, y, width, height]).allSatisfy { abs($0 - $1) < 0.0001 }, "\(box.rect)")
    }

    @Test func movesInsideTheScreen() {
        expect(box.moved(by: CGSize(width: 40, height: -80), in: size), 0.35, 0.15, 0.5, 0.25)
        expect(box.moved(by: CGSize(width: 9999, height: 9999), in: size), 0.5, 0.75, 0.5, 0.25)
        expect(box.moved(by: CGSize(width: -9999, height: -9999), in: size), 0, 0, 0.5, 0.25)
    }

    @Test func cornersKeepTheOppositeCorner() {
        expect(box.resized(.topLeft, by: CGSize(width: -40, height: -80), in: size), 0.15, 0.15, 0.6, 0.35)
        expect(box.resized(.topRight, by: CGSize(width: 40, height: -80), in: size), 0.25, 0.15, 0.6, 0.35)
        expect(box.resized(.bottomLeft, by: CGSize(width: -40, height: 80), in: size), 0.15, 0.25, 0.6, 0.35)
        expect(box.resized(.bottomRight, by: CGSize(width: 40, height: 80), in: size), 0.25, 0.25, 0.6, 0.35)
    }

    @Test(arguments: ScanBox.Handle.allCases)
    func neverSmallerThanUsableOrOutside(corner: ScanBox.Handle) {
        for offset in [CGSize(width: 9999, height: 9999), CGSize(width: -9999, height: -9999)] {
            let rect = box.resized(corner, by: offset, in: size).rect
            #expect(rect.width >= ScanBox.minimumWidth - 0.0001 && rect.height >= ScanBox.minimumHeight - 0.0001)
            #expect(rect.minX >= 0 && rect.minY >= 0 && rect.maxX <= 1.0001 && rect.maxY <= 1.0001)
        }
    }

    @Test func sidesMoveOnlyThemselves() {
        expect(box.resized(.top, by: CGSize(width: 99, height: -80), in: size), 0.25, 0.15, 0.5, 0.35)
        expect(box.resized(.bottom, by: CGSize(width: 99, height: 80), in: size), 0.25, 0.25, 0.5, 0.35)
        expect(box.resized(.left, by: CGSize(width: -40, height: 99), in: size), 0.15, 0.25, 0.6, 0.25)
        expect(box.resized(.right, by: CGSize(width: 40, height: 99), in: size), 0.25, 0.25, 0.6, 0.25)
    }

    @Test func isRememberedAndDamagedValuesAreRejected() {
        #expect(ScanBox(rawValue: box.rawValue) == box)
        for bad in ["", "1 2 3", "a b c d", "nan 0 1 1"] { #expect(ScanBox(rawValue: bad) == nil) }
    }

    @Test func emptyContainerIsHarmless() {
        #expect(box.moved(by: CGSize(width: 5, height: 5), in: .zero) == box)
    }
}

struct TextStabilizerTests {
    @Test func waitsForTwoAgreeingFrames() {
        var stabilizer = TextStabilizer()
        #expect(stabilizer.update(["Follow the car"]) == nil)
        #expect(stabilizer.update(["Follow the car"]) == ["Follow the car"])
        #expect(stabilizer.update(["Follow the car"]) == nil)
    }

    @Test func smallMisreadingsChangeNothing() {
        var stabilizer = TextStabilizer()
        _ = stabilizer.update(["Get back to the safehouse"])
        _ = stabilizer.update(["Get back to the safehouse"])
        #expect(stabilizer.update(["Get back to the safehovse"]) == nil)
        #expect(stabilizer.update(["Get back to the safehovse"]) == nil)
        #expect(stabilizer.current == ["Get back to the safehouse"])
    }

    @Test func passingGarbageIsIgnored() {
        var stabilizer = TextStabilizer()
        #expect(stabilizer.update(["qwzx lkj"]) == nil)
        #expect(stabilizer.update(["Follow the car"]) == nil)
        #expect(stabilizer.update(["Follow the car"]) == ["Follow the car"])
    }

    @Test func briefLossKeepsTheText() {
        var stabilizer = TextStabilizer()
        _ = stabilizer.update(["Follow the car"])
        _ = stabilizer.update(["Follow the car"])
        for _ in 1..<TextStabilizer.emptyFramesToClear { #expect(stabilizer.update([]) == nil) }
        #expect(stabilizer.update([]) == [])
        #expect(stabilizer.current.isEmpty)
        #expect(stabilizer.update([]) == nil)
    }

    @Test func trustedFrameIsAcceptedAtOnceAndConfirmedLater() {
        var stabilizer = TextStabilizer()
        #expect(stabilizer.update(["Follow the car"], isTrusted: true) == ["Follow the car"])
        #expect(!stabilizer.isConfirmed)
        #expect(stabilizer.update(["Follow the car"], isTrusted: true) == nil)
        #expect(stabilizer.isConfirmed)
        #expect(stabilizer.update(["Lose the police"], isTrusted: true) == ["Lose the police"])
        #expect(!stabilizer.isConfirmed)
    }

    @Test func realChangeIsAccepted() {
        var stabilizer = TextStabilizer()
        _ = stabilizer.update(["Follow the car"])
        _ = stabilizer.update(["Follow the car"])
        #expect(stabilizer.update(["Lose the police"]) == nil)
        #expect(stabilizer.update(["Lose the police"]) == ["Lose the police"])
    }

    @Test func acceptsNothing() {
        var stabilizer = TextStabilizer()
        #expect(stabilizer.update([]) == nil)
    }
}

struct ReadingStatusTests {
    private func reading(_ texts: [String], pixelHeight: CGFloat = 400, isStill: Bool = false) -> CameraReading {
        CameraReading(
            lines: texts.map { RecognizedLine(text: $0, boundingBox: CGRect(x: 0, y: 0, width: 1, height: 0.1)) },
            pixelHeight: pixelHeight, isStill: isStill
        )
    }

    @Test func largeTextIsRead() {
        var tracker = ReadingStatusTracker()
        #expect(tracker.status(for: reading(["Follow the car"])) == .reading)
    }

    @Test func smallTextAsksToMoveCloser() {
        var tracker = ReadingStatusTracker()
        #expect(tracker.status(for: reading(["Follow the car"], pixelHeight: 100)) == .moveCloser)
    }

    @Test func emptyBoxIsReportedOnlyAfterAWhile() {
        var tracker = ReadingStatusTracker()
        #expect(tracker.status(for: reading([])) == .searching)
        #expect(tracker.status(for: reading(["|", "12:30"])) == .searching)
        #expect(tracker.status(for: reading([])) == .noText)
        #expect(tracker.status(for: reading(["Follow the car"])) == .reading)
        #expect(tracker.status(for: reading([])) == .searching)
    }

    @Test func frozenPictureKnowsAtOnce() {
        var tracker = ReadingStatusTracker()
        #expect(tracker.status(for: reading([], isStill: true)) == .noText)
    }
}

@MainActor
struct BoxPresetTests {
    @Test(arguments: BoxPreset.allCases)
    func presetIsRecognizedEvenAfterBeingSaved(preset: BoxPreset) throws {
        #expect(BoxPreset.matching(preset.box) == preset)
        #expect(BoxPreset.matching(try #require(ScanBox(rawValue: preset.box.rawValue))) == preset)
    }

    @Test func movedBoxMatchesNothing() {
        let moved = ScanBox.standard.moved(by: CGSize(width: 10, height: 0), in: CGSize(width: 300, height: 500))
        #expect(BoxPreset.matching(moved) == nil)
    }
}

@MainActor
struct OverlayPlacementTests {
    private let size = CGSize(width: 360, height: 520)

    private func place(_ box: CGRect, in size: CGSize? = nil) -> CGRect {
        OverlayPlacement(box: box, in: size ?? self.size, top: 72).frame
    }

    @Test func goesBelowWhenThereIsRoom() {
        let box = CGRect(x: 20, y: 200, width: 300, height: 80)
        #expect(place(box).minY >= box.maxY + OverlayPlacement.statusHeight)
        #expect(place(box).maxY <= size.height)
    }

    @Test func goesAboveABoxAtTheBottom() {
        let box = CGRect(x: 20, y: 420, width: 300, height: 90)
        #expect(place(box).maxY <= box.minY)
        #expect(place(box).minY >= 72)
    }

    @Test func coversTheEndOfABoxThatFillsThePicture() {
        let frame = place(CGRect(x: 0, y: 20, width: 360, height: 490))
        #expect(frame.height >= OverlayPlacement.comfortableHeight)
        #expect(frame.maxY <= size.height)
    }

    @Test func staysClearOfControlsAtTheBottom() {
        let full = CGSize(width: 402, height: 780)
        for preset in BoxPreset.allCases {
            let frame = OverlayPlacement(box: preset.box.frame(in: full), in: full, top: 72, bottom: 104).frame
            #expect(frame.maxY <= full.height - 104)
            #expect(frame.height >= 48)
        }
    }

    /// Phones of every shape, upright and sideways, in and out of full screen.
    @Test(arguments: BoxPreset.allCases, [
        CGSize(width: 351, height: 470), CGSize(width: 378, height: 560), CGSize(width: 402, height: 874),
        CGSize(width: 460, height: 360), CGSize(width: 874, height: 402), CGSize(width: 900, height: 700)
    ])
    func everyPresetLeavesAUsableOverlay(preset: BoxPreset, size: CGSize) {
        let frame = place(preset.box.frame(in: size), in: size)
        #expect(frame.height >= 48, "\(preset) \(size) \(frame)")
        #expect(frame.minY >= 0 && frame.maxY <= size.height && frame.width > 200)
    }
}
