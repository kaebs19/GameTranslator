import CoreGraphics
import Foundation
import Testing
@testable import GameTranslator

@MainActor
struct CameraViewModelTests {
    private let camera = StubCamera()
    private let translator = StubTranslator()
    private let settings = InMemorySettingsStore()
    private let history = StubHistory()
    private let languages = StubLanguages()
    private let speaker = StubSpeaker()
    private let tv = StubTV()
    private let refiner = StubRefiner()
    private let screen = Screen()

    private final class Screen {
        var isOn = false
    }

    private let clock = Clock()

    private final class Clock {
        var now: TimeInterval = 0
    }

    private func makeViewModel() -> CameraViewModel {
        CameraViewModel(
            camera: camera, translator: translator, languages: languages, speaker: speaker,
            settings: settings, history: history, tv: tv, refiner: refiner, readableLanguages: [.english, AppLanguage(code: "fr")],
            keepScreenOn: { screen.isOn = $0 }, now: { [clock] in clock.now }
        )
    }

    private func started() async -> CameraViewModel {
        let viewModel = makeViewModel()
        await viewModel.start()
        if viewModel.state == .running { viewModel.toggleTranslating() }
        return viewModel
    }

    private func change(_ body: (inout AppSettings) -> Void) {
        var current = settings.load()
        body(&current)
        settings.save(current)
    }

    private func translations(_ viewModel: CameraViewModel) -> [String?] { viewModel.items.map(\.translation) }

    @Test func translatesWhatTheBoxShows() async throws {
        let viewModel = await started()
        #expect(viewModel.state == .running && camera.language == .english)
        camera.see(["Follow the car", "12:30"])
        #expect(try await eventually { translations(viewModel) == ["ar:Follow the car"] })
    }

    @Test func sameTextIsTranslatedOnce() async throws {
        let viewModel = await started()
        camera.see(["Follow the car"], frames: 12)
        #expect(try await eventually { translations(viewModel) == ["ar:Follow the car"] })
        try await Task.sleep(for: .milliseconds(100))
        #expect(translator.requests.count == 1)
    }

    @Test func remainingLineKeepsItsTranslation() async throws {
        let viewModel = await started()
        camera.see(["Follow the car"])
        #expect(try await eventually { translations(viewModel) == ["ar:Follow the car"] })
        camera.see(["Follow the car", "Lose the police"])
        #expect(try await eventually { translations(viewModel) == ["ar:Follow the car", "ar:Lose the police"] })
        #expect(translator.requests == [["Follow the car"], ["Lose the police"]])
    }

    /// The phone has room for the last translation; the TV shows it over the game.
    @Test func emptyBoxKeepsTheResultAndClearsTheTV() async throws {
        let viewModel = await started()
        camera.see(["Follow the car"])
        #expect(try await eventually { tv.shown == ["ar:Follow the car"] })
        camera.see([], frames: 3)
        #expect(try await eventually { viewModel.status == .noText })
        #expect(tv.shown == ["ar:Follow the car"])
        clock.now += TextStabilizer.holdTime
        camera.see([], frames: 1)
        #expect(try await eventually { tv.shown.isEmpty })
        #expect(translations(viewModel) == ["ar:Follow the car"])
        viewModel.toggleTranslating()
        viewModel.toggleTranslating()
        #expect(tv.shown.isEmpty)
        camera.see(["Follow the car"])
        #expect(try await eventually { tv.shown == ["ar:Follow the car"] })
        #expect(translator.requests.count == 1)
    }

    @Test func lastTranslationStaysUntilTheNextIsReady() async throws {
        let viewModel = await started()
        camera.see(["Follow the car"])
        #expect(try await eventually { viewModel.translatedText == "ar:Follow the car" })
        var finish: CheckedContinuation<Void, Never>?
        translator.translate = { texts in
            await withCheckedContinuation { finish = $0 }
            return Dictionary(texts.map { ($0, "ar:" + $0) }) { first, _ in first }
        }
        camera.see(["Lose the police"])
        #expect(try await eventually { finish != nil })
        #expect(viewModel.items.map(\.original) == ["Lose the police"])
        #expect(viewModel.translatedText == "ar:Follow the car")
        finish?.resume()
        #expect(try await eventually { viewModel.translatedText == "ar:Lose the police" })
    }

    @Test func nothingIsReadUntilAsked() async throws {
        let viewModel = makeViewModel()
        await viewModel.start()
        #expect(viewModel.state == .running && !viewModel.isTranslating && !camera.isReading)
        camera.see(["Follow the car"])
        try await Task.sleep(for: .milliseconds(100))
        #expect(viewModel.items.isEmpty)
        viewModel.toggleTranslating()
        #expect(camera.isReading)
        camera.see(["Follow the car"])
        #expect(try await eventually { translations(viewModel) == ["ar:Follow the car"] })
    }

    @Test func stoppingKeepsTheTextOnScreen() async throws {
        let viewModel = await started()
        camera.see(["Follow the car"])
        #expect(try await eventually { translations(viewModel) == ["ar:Follow the car"] })
        viewModel.toggleTranslating()
        #expect(!camera.isReading)
        camera.see(["Lose the police"], frames: 4)
        try await Task.sleep(for: .milliseconds(100))
        #expect(viewModel.items.map(\.original) == ["Follow the car"])
    }

    @Test func editingTheBoxPausesReading() async {
        let viewModel = await started()
        viewModel.toggleEditingBox()
        #expect(viewModel.isEditingBox && viewModel.isTranslating && !camera.isReading)
        viewModel.toggleEditingBox()
        #expect(camera.isReading)
        viewModel.toggleTranslating()
        viewModel.toggleEditingBox()
        viewModel.toggleTranslating()
        #expect(!viewModel.isEditingBox && camera.isReading)
    }

    @Test func singleShotStopsAfterOneResult() async throws {
        change { $0.reading.isContinuous = false }
        let viewModel = await started()
        camera.see(["Follow the car"])
        #expect(try await eventually { translations(viewModel) == ["ar:Follow the car"] })
        #expect(!viewModel.isTranslating && !camera.isReading)
    }

    @Test func clearingEmptiesTheCard() async throws {
        let viewModel = await started()
        camera.see(["Follow the car"])
        #expect(try await eventually { !viewModel.items.isEmpty })
        viewModel.clearResult()
        #expect(viewModel.items.isEmpty)
    }

    @Test func resultsGoToHistory() async throws {
        let viewModel = await started()
        camera.see(["Follow the car"])
        #expect(try await eventually { !history.recorded.isEmpty })
        #expect(history.recorded.map(\.translation) == ["ar:Follow the car"])
        #expect(history.recorded.first?.source == .camera)
        _ = viewModel
    }

    @Test func swappingLanguagesRestartsTheCamera() async throws {
        change { $0.target = AppLanguage(code: "fr") }
        let viewModel = await started()
        camera.see(["Follow the car"])
        #expect(try await eventually { !viewModel.items.isEmpty })
        #expect(viewModel.canSwapLanguages)
        await viewModel.swapLanguages()
        #expect(settings.load().pair == LanguagePair(source: "fr", target: "en"))
        #expect(camera.language == AppLanguage(code: "fr") && viewModel.state == .running)
        #expect(viewModel.items.isEmpty && viewModel.isTranslating && camera.isReading)
    }

    @Test func unreadableTargetCannotBeSwapped() async {
        let viewModel = await started()
        #expect(!viewModel.canSwapLanguages)
        await viewModel.swapLanguages()
        #expect(settings.load().pair == LanguagePair(source: "en", target: "ar"))
    }

    /// The camera may restart before or after it hears about the change.
    @Test(arguments: [true, false])
    func oldTranslationsDisappearWithTheLanguage(startsFirst: Bool) async throws {
        let viewModel = await started()
        camera.see(["Follow the car"])
        #expect(try await eventually { !viewModel.items.isEmpty })
        viewModel.stop()
        change { $0.target = AppLanguage(code: "fr") }
        if startsFirst { await viewModel.start() }
        viewModel.settingsDidChange()
        if !startsFirst { await viewModel.start() }
        #expect(viewModel.items.isEmpty)
        #expect(viewModel.state == .running)
    }

    @Test func displayOptionsApplyWithoutRestart() async throws {
        let viewModel = await started()
        camera.see(["Follow the car"])
        #expect(try await eventually { !viewModel.items.isEmpty })
        change { $0.reading.textSize = .large }
        viewModel.settingsDidChange()
        #expect(viewModel.current.reading.textSize == .large)
        #expect(viewModel.state == .running && !viewModel.items.isEmpty)
    }

    @Test func translationErrorCanBeRetried() async throws {
        let viewModel = await started()
        let working = translator.translate
        translator.translate = { _ in throw AppError.unsupportedLanguages }
        camera.see(["Follow the car"])
        #expect(try await eventually { viewModel.translationError == .unsupportedLanguages })
        translator.translate = working
        viewModel.retryTranslation()
        #expect(try await eventually { translations(viewModel) == ["ar:Follow the car"] })
        #expect(viewModel.translationError == nil)
    }

    @Test func explainsWhyItCannotStart() async {
        camera.isAllowed = false
        #expect(await started().state == .failed(.cameraAccessDenied))
        camera.isAllowed = true
        settings.save(AppSettings(source: AppLanguage(code: "he")))
        #expect(await started().state == .failed(.cameraLanguageUnsupported))
        settings.save(AppSettings(source: .english, target: .english))
        #expect(await started().state == .failed(.sameLanguage))
        camera.session = nil
        #expect(await started().state == .failed(.cameraUnavailable))
        #expect(!camera.isRunning)
    }

    @Test func stopTurnsEverythingOff() async {
        let viewModel = await started()
        viewModel.toggleTorch()
        #expect(camera.torch)
        viewModel.stop()
        #expect(viewModel.state == .idle && !camera.isRunning && !viewModel.isTorchOn)
    }

    // MARK: Screen

    @Test func screenStaysOnOnlyWhileReading() async {
        let viewModel = makeViewModel()
        await viewModel.start()
        #expect(!screen.isOn)
        viewModel.toggleTranslating()
        #expect(screen.isOn)
        viewModel.toggleTranslating()
        #expect(!screen.isOn)
        viewModel.toggleTranslating()
        viewModel.stop()
        #expect(!screen.isOn)
        await viewModel.start()
        #expect(screen.isOn)
    }

    // MARK: Status

    @Test func statusFollowsTheCamera() async throws {
        let viewModel = makeViewModel()
        await viewModel.start()
        #expect(viewModel.status == .paused)
        viewModel.toggleTranslating()
        #expect(viewModel.status == .searching)
        camera.see(["Follow the car"], frames: 1, pixelHeight: 50)
        #expect(try await eventually { viewModel.status == .moveCloser })
        camera.see(["Follow the car"], frames: 1)
        #expect(try await eventually { viewModel.status == .reading })
        camera.see([], frames: 3)
        #expect(try await eventually { viewModel.status == .noText })
        viewModel.toggleEditingBox()
        #expect(viewModel.status == .paused)
    }

    // MARK: Freeze

    @Test func freezingReadsOnePictureAtOnce() async throws {
        let viewModel = makeViewModel()
        await viewModel.start()
        viewModel.toggleFreeze()
        #expect(viewModel.isFrozen && camera.isFrozen && !camera.isReading && screen.isOn)
        camera.showStill(try #require(TestImage.make(lines: ["x"])))
        #expect(try await eventually { viewModel.stillImage != nil })
        camera.see(["Follow the car"], frames: 1, isStill: true)
        #expect(try await eventually { translations(viewModel) == ["ar:Follow the car"] })
    }

    /// Events arrive in order, so a later one that shows up proves the earlier one was dropped.
    @Test func frozenPictureIgnoresTheLiveOne() async throws {
        let viewModel = await started()
        viewModel.toggleFreeze()
        camera.see(["Lose the police"], frames: 4)
        camera.see(["Follow the car"], frames: 1, isStill: true)
        #expect(try await eventually { !viewModel.items.isEmpty })
        #expect(viewModel.items.map(\.original) == ["Follow the car"])
        viewModel.toggleFreeze()
        #expect(!viewModel.isFrozen && viewModel.stillImage == nil && camera.isReading)
        camera.see(["Return home now"], frames: 1, isStill: true)
        camera.see(["Open the gate"])
        #expect(try await eventually { viewModel.items.map(\.original) != ["Follow the car"] })
        #expect(viewModel.items.map(\.original) == ["Open the gate"])
    }

    @Test func boxMayMoveOverAFrozenPicture() async throws {
        let viewModel = await started()
        viewModel.toggleFreeze()
        viewModel.toggleEditingBox()
        camera.see(["Follow the car"], frames: 1, isStill: true)
        #expect(try await eventually { translations(viewModel) == ["ar:Follow the car"] })
        camera.see(["Lose the police"], frames: 1, isStill: true)
        #expect(try await eventually { translations(viewModel) == ["ar:Lose the police"] })
    }

    @Test func turningThePhoneEndsTheFreeze() async {
        let viewModel = await started()
        func turn(_ angle: CGFloat) {
            viewModel.setRegion(CameraRegion(rect: .zero, rotationAngle: angle), aspectRatio: 2)
        }
        turn(90)
        viewModel.toggleFreeze()
        turn(90)
        #expect(viewModel.isFrozen)
        turn(0)
        #expect(!viewModel.isFrozen && !camera.isFrozen)
    }

    @Test func leavingEndsTheFreeze() async {
        let viewModel = await started()
        viewModel.toggleFreeze()
        viewModel.stop()
        #expect(!viewModel.isFrozen && !camera.isFrozen)
    }

    // MARK: Languages

    @Test func downloadIsOfferedAndUpdatesTheState() async {
        languages.readiness = .downloadable
        let viewModel = await started()
        #expect(viewModel.readiness == .downloadable)
        await viewModel.downloadLanguages()
        #expect(languages.prepared == [LanguagePair(source: "en", target: "ar")])
        #expect(viewModel.readiness == .ready && !viewModel.isDownloading)
        await viewModel.downloadLanguages()
        #expect(languages.prepared.count == 1)
    }

    @Test func decliningTheDownloadIsNotAnError() async {
        languages.readiness = .downloadable
        languages.prepareError = CocoaError(.userCancelled)
        let viewModel = await started()
        await viewModel.downloadLanguages()
        #expect(viewModel.translationError == nil && viewModel.readiness == .downloadable)
        languages.prepareError = AppError.unsupportedLanguages
        await viewModel.downloadLanguages()
        #expect(viewModel.translationError == .unsupportedLanguages)
    }

    @Test func firstTranslationRefreshesReadiness() async throws {
        languages.readiness = .downloadable
        let viewModel = await started()
        languages.readiness = .ready
        camera.see(["Follow the car"])
        #expect(try await eventually { viewModel.readiness == .ready })
    }

    // MARK: Speech

    @Test func speaksTheTranslationInItsLanguage() async throws {
        let viewModel = await started()
        viewModel.toggleSpeaking()
        #expect(speaker.spoken.isEmpty)
        camera.see(["Follow the car"])
        #expect(try await eventually { !viewModel.translatedText.isEmpty })
        viewModel.toggleSpeaking()
        #expect(speaker.spoken.map(\.text) == ["ar:Follow the car"])
        #expect(speaker.spoken.first?.language == .arabic)
        viewModel.toggleSpeaking()
        #expect(!speaker.isSpeaking)
        viewModel.toggleSpeaking()
        viewModel.clearResult()
        #expect(!speaker.isSpeaking)
    }

    @Test func zoomStaysInRange() async {
        let viewModel = await started()
        viewModel.setZoom(99)
        #expect(viewModel.zoom == CameraViewModel.maximumZoom && camera.zoom == CameraViewModel.maximumZoom)
        viewModel.setZoom(0.1)
        #expect(viewModel.zoom == 1)
    }

    // MARK: Fast mode

    private func startedFast() async -> CameraViewModel {
        change { $0.reading.speed = .fast }
        return await started()
    }

    @Test func fastModeLooksMoreOften() async {
        let viewModel = await started()
        let balanced = camera.interval
        #expect(balanced == 0.4)
        change { $0.reading.speed = .fast }
        viewModel.settingsDidChange()
        #expect(camera.interval < balanced / 2)
        #expect(viewModel.state == .running)
    }

    @Test func fastModeShowsTheFirstClearReading() async throws {
        let viewModel = await startedFast()
        camera.see(["Follow the car"], frames: 1)
        #expect(try await eventually { translations(viewModel) == ["ar:Follow the car"] })
    }

    /// Low confidence and tiny text both mean the frame may be wrong.
    @Test(arguments: [(Float(0.3), CGFloat(500)), (1, 50)])
    func fastModeStillChecksUnclearReadings(confidence: Float, pixelHeight: CGFloat) async throws {
        let viewModel = await startedFast()
        camera.see(["Follow the cat"], frames: 1, pixelHeight: pixelHeight, confidence: confidence)
        camera.see(["Lose the police"], frames: 1)
        #expect(try await eventually { !viewModel.items.isEmpty })
        #expect(viewModel.items.map(\.original) == ["Lose the police"])
    }

    @Test func unclearTextIsAcceptedOnceTwoReadingsAgree() async throws {
        let viewModel = await startedFast()
        camera.see(["Follow the car"], frames: 2, confidence: 0.3)
        #expect(try await eventually { translations(viewModel) == ["ar:Follow the car"] })
    }

    @Test func onlyConfirmedTextEntersHistory() async throws {
        let viewModel = await startedFast()
        camera.see(["Folow teh caar"], frames: 1)
        #expect(try await eventually { translations(viewModel) == ["ar:Folow teh caar"] })
        #expect(history.recorded.isEmpty)
        camera.see(["Lose the police"], frames: 1)
        #expect(try await eventually { translations(viewModel) == ["ar:Lose the police"] })
        camera.see(["Lose the police"], frames: 1)
        #expect(try await eventually { !history.recorded.isEmpty })
        #expect(history.recorded.map(\.original) == ["Lose the police"])
    }

    @Test func confirmationBeforeTheTranslationArrivesIsNotLost() async throws {
        let viewModel = await startedFast()
        var finish: CheckedContinuation<Void, Never>?
        translator.translate = { texts in
            await withCheckedContinuation { finish = $0 }
            return Dictionary(texts.map { ($0, "ar") }) { first, _ in first }
        }
        camera.see(["Follow the car"], frames: 3)
        #expect(try await eventually { finish != nil })
        try await Task.sleep(for: .milliseconds(100))
        finish?.resume()
        #expect(try await eventually { history.recorded.map(\.original) == ["Follow the car"] })
        _ = viewModel
    }

    @Test func fastSingleShotIsRecorded() async throws {
        change { $0.reading.isContinuous = false }
        let viewModel = await startedFast()
        camera.see(["Follow the car"], frames: 1)
        #expect(try await eventually { !viewModel.isTranslating })
        #expect(history.recorded.map(\.original) == ["Follow the car"])
    }

    // MARK: Server

    @Test func betterTranslationReplacesTheInstantOne() async throws {
        refiner.answer = ["Lose the police": "تخلّص من الشرطة"]
        let viewModel = await started()
        camera.see(["Follow the car"])
        #expect(try await eventually { translations(viewModel) == ["ar:Follow the car"] })
        camera.see(["Lose the police"])
        #expect(try await eventually { translations(viewModel) == ["تخلّص من الشرطة"] })
        #expect(tv.shown == ["تخلّص من الشرطة"])
        // The line read before helps the server understand this one.
        #expect(refiner.requests.last?.context == ["Follow the car"])
    }

    // MARK: Sharing

    @Test func sharesWhatIsShown() async throws {
        let viewModel = await started()
        #expect(viewModel.shared == nil)
        camera.see(["Follow the car"])
        #expect(try await eventually { viewModel.shared != nil })
        #expect(viewModel.shared?.text == "ar:Follow the car\nFollow the car")
        change { $0.reading.showsOriginal = false }
        viewModel.settingsDidChange()
        #expect(viewModel.shared?.text == "ar:Follow the car")
    }

    @Test func tvShowsTranslationsAndClearsWhenPaused() async throws {
        let viewModel = await started()
        camera.see(["Follow the car"])
        #expect(try await eventually { tv.shown == ["ar:Follow the car"] })
        camera.see(["Lose the police"])
        #expect(try await eventually { tv.shown == ["ar:Lose the police"] })
        // The old line stayed until the new one was ready.
        #expect(!tv.history.drop { $0.isEmpty }.contains([]))
        viewModel.toggleTranslating()
        #expect(tv.shown.isEmpty)
        viewModel.toggleTranslating()
        #expect(tv.shown == ["ar:Lose the police"])
        viewModel.stop()
        #expect(tv.shown.isEmpty)
    }
}
