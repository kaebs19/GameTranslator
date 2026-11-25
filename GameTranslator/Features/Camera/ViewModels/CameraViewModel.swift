import AVFoundation
import Foundation
import Observation

/// Camera frames → stable text → translation.
@Observable
final class CameraViewModel {
    enum State: Equatable {
        case idle, running
        case failed(AppError)
    }

    struct Item: Identifiable, Equatable {
        let id: UUID
        let original: String
        var translation: String?
    }

    private(set) var state: State = .idle
    private(set) var items: [Item] = []
    /// The user started reading. The picture is shown either way.
    private(set) var isTranslating = false
    private(set) var isEditingBox = false
    private(set) var isFrozen = false
    /// The frozen picture, upright.
    private(set) var stillImage: CGImage?
    private(set) var status = ReadingStatus.paused
    private(set) var current: AppSettings
    private(set) var isTorchOn = false
    private(set) var zoom: CGFloat = 1
    private(set) var readiness = LanguageReadiness.unknown
    private(set) var isDownloading = false
    private(set) var translationError: AppError?

    private let camera: any CameraProviding
    private let translator: any TranslationProviding
    private let languages: any LanguagePreparing
    private let speaker: any Speaking
    private let settings: any SettingsStoring
    private let history: any HistoryRecording
    private let readableLanguages: Set<AppLanguage>
    /// A phone on a stand is not touched, and would lock in the middle of a game.
    private let keepScreenOn: (Bool) -> Void
    @ObservationIgnored private var stabilizer = TextStabilizer()
    /// Translations of text only one frame has shown so far.
    @ObservationIgnored private var unconfirmed: [(original: String, translation: String)] = []
    @ObservationIgnored private var statusTracker = ReadingStatusTracker()
    @ObservationIgnored private var reading: Task<Void, Never>?
    @ObservationIgnored private var translation: Task<Void, Never>?
    @ObservationIgnored private var region: CameraRegion?
    @ObservationIgnored private var regionAspect: CGFloat = 1

    init(
        camera: any CameraProviding, translator: any TranslationProviding, languages: any LanguagePreparing,
        speaker: any Speaking, settings: any SettingsStoring, history: any HistoryRecording,
        readableLanguages: Set<AppLanguage>, keepScreenOn: @escaping (Bool) -> Void
    ) {
        self.camera = camera
        self.translator = translator
        self.languages = languages
        self.speaker = speaker
        self.settings = settings
        self.history = history
        self.keepScreenOn = keepScreenOn
        current = settings.load()
        self.readableLanguages = readableLanguages
    }

    var session: AVCaptureSession? { camera.session }
    var hasTorch: Bool { camera.hasTorch }

    // MARK: Lifecycle

    func start() async {
        guard state != .running else { return }
        guard camera.session != nil else { return state = .failed(.cameraUnavailable) }
        guard await camera.requestAccess() else { return state = .failed(.cameraAccessDenied) }
        guard !Task.isCancelled else { return }
        adoptSettings()
        guard !current.pair.isSameLanguage else { return state = .failed(.sameLanguage) }
        guard readableLanguages.contains(current.source) else { return state = .failed(.cameraLanguageUnsupported) }
        state = .running
        applySpeed()
        let stream = camera.start(language: current.source)
        updateReading()
        reading = Task { [weak self] in
            for await event in stream { self?.handle(event) }
        }
        await refreshReadiness()
    }

    func stop() {
        reading?.cancel()
        reading = nil
        camera.stop()
        speaker.stop()
        isTorchOn = false
        endFreeze()
        // An error stays visible behind whatever opened; the next start tries again.
        if state == .running { state = .idle }
        updateReading()
    }

    func retry() async {
        stop()
        await start()
    }

    /// Languages or display options may have changed.
    func settingsDidChange() {
        guard adoptSettings(), state != .idle else { return }
        // The next start picks up the new language.
        stop()
    }

    /// Returns whether the languages changed, in which case old results are gone.
    @discardableResult
    private func adoptSettings() -> Bool {
        let previous = current
        current = settings.load()
        applySpeed()
        guard current.pair != previous.pair else { return false }
        readiness = .unknown
        clearResult()
        return true
    }

    private func applySpeed() { camera.setInterval(current.reading.speed.interval) }

    // MARK: Picture

    /// `aspectRatio` is the box's width over its height on screen.
    func setRegion(_ region: CameraRegion, aspectRatio: CGFloat) {
        // A frozen picture was turned for the old orientation and would no longer match the box.
        if isFrozen, let old = self.region, old.rotationAngle != region.rotationAngle { toggleFreeze() }
        self.region = region
        regionAspect = aspectRatio
        camera.setRegion(region)
    }

    static let maximumZoom: CGFloat = 6

    /// Kept here because the picture is rebuilt when it goes full screen.
    func setZoom(_ factor: CGFloat) {
        zoom = min(max(1, factor), Self.maximumZoom)
        camera.setZoom(zoom)
    }

    func toggleTorch() {
        isTorchOn.toggle()
        camera.setTorch(isTorchOn)
    }

    // MARK: Reading controls

    func toggleTranslating() {
        isTranslating.toggle()
        if isTranslating { isEditingBox = false }
        if isFrozen { endFreeze() }
        updateReading()
    }

    /// Live reading waits while the box is being changed.
    func toggleEditingBox() {
        isEditingBox.toggle()
        stabilizer.reset()
        updateReading()
    }

    /// Holds one picture still so fast text can be read in peace.
    func toggleFreeze() {
        guard state == .running else { return }
        if isFrozen {
            endFreeze()
        } else {
            isFrozen = true
            stabilizer.reset()
            camera.setFrozen(true)
        }
        updateReading()
    }

    private func endFreeze() {
        guard isFrozen else { return }
        isFrozen = false
        stillImage = nil
        stabilizer.reset()
        camera.setFrozen(false)
    }

    private var isReadingLive: Bool { state == .running && isTranslating && !isEditingBox && !isFrozen }

    private func updateReading() {
        camera.setReading(isReadingLive)
        keepScreenOn(state == .running && (isTranslating || isFrozen))
        statusTracker.reset()
        status = isReadingLive || isFrozen ? .searching : .paused
    }

    // MARK: Languages

    var canSwapLanguages: Bool { readableLanguages.contains(current.target) }

    func swapLanguages() async {
        guard canSwapLanguages else { return }
        var swapped = settings.load()
        (swapped.source, swapped.target) = (swapped.target, swapped.source)
        settings.save(swapped)
        let wasRunning = state != .idle
        settingsDidChange()
        if wasRunning { await start() }
    }

    func refreshReadiness() async {
        let pair = current.pair
        let result = await languages.readiness(of: pair)
        if pair == current.pair { readiness = result }
    }

    func downloadLanguages() async {
        guard readiness == .downloadable, !isDownloading else { return }
        isDownloading = true
        defer { isDownloading = false }
        do {
            try await languages.prepare(current.pair)
        } catch is CancellationError {
            // Stopped by us.
        } catch let error as CocoaError where error.code == .userCancelled {
            // The user closed the system's sheet.
        } catch {
            translationError = AppError(error)
        }
        await refreshReadiness()
    }

    // MARK: Result

    var hasResult: Bool { !items.isEmpty || translationError != nil }

    /// All translations shown, ready to copy or read aloud.
    var translatedText: String { items.compactMap(\.translation).joined(separator: "\n") }

    var isSpeaking: Bool { speaker.isSpeaking }

    func toggleSpeaking() {
        if speaker.isSpeaking {
            speaker.stop()
        } else if !translatedText.isEmpty {
            speaker.speak(translatedText, language: current.target)
        }
    }

    func retryTranslation() { translate() }

    func clearResult() {
        translation?.cancel()
        speaker.stop()
        stabilizer.reset()
        unconfirmed = []
        items = []
        translationError = nil
    }

    // MARK: Pipeline

    private func handle(_ event: CameraEvent) {
        switch event {
        case .still(let image):
            if isFrozen { stillImage = image }
        case .reading(let reading):
            receive(reading)
        }
    }

    private func receive(_ reading: CameraReading) {
        // A reading from before the last switch between live and frozen is out of date.
        guard reading.isStill == isFrozen, isFrozen || isReadingLive else { return }
        status = statusTracker.status(for: reading)
        let readable = reading.lines.filter { TextNormalizer.looksLikeText($0.text) }
        let texts = LineMerger.blocks(from: readable, aspectRatio: regionAspect).map(\.text)
        let changed = isFrozen ? changedStill(texts) : stabilizer.update(texts, isTrusted: isClear(readable))
        guard let changed else { return recordConfirmed() }
        // Replaced before a second frame agreed: most likely misread while moving.
        unconfirmed = []
        items = changed.map { text in
            // Lines that were already there keep their translation while the rest arrives.
            items.first { $0.original == text } ?? Item(id: UUID(), original: text)
        }
        translate()
    }

    /// Blurred frames still wait for a second one, even in fast mode.
    private func isClear(_ lines: [RecognizedLine]) -> Bool {
        current.reading.speed == .fast && status == .reading
            && lines.allSatisfy { $0.confidence >= ReadingSettings.Speed.clearConfidence }
    }

    private func recordConfirmed() {
        guard stabilizer.isConfirmed, !unconfirmed.isEmpty else { return }
        history.record(unconfirmed, pair: current.pair, source: .camera)
        unconfirmed = []
    }

    /// A frozen picture reads the same every time, so one reading is enough.
    private func changedStill(_ texts: [String]) -> [String]? {
        texts == items.map(\.original) ? nil : texts
    }

    private func translate() {
        translation?.cancel()
        translationError = nil
        let texts = items.filter { $0.translation == nil }.map(\.original)
        guard !texts.isEmpty else { return }
        let pair = settings.load().pair
        translation = Task { [weak self, translator] in
            do {
                let result = try await translator.translations(for: texts, pair: pair)
                guard !Task.isCancelled else { return }
                await self?.apply(result, pair: pair)
            } catch {
                guard !Task.isCancelled else { return }
                self?.translationError = AppError(error)
            }
        }
    }

    private func apply(_ translations: [String: String], pair: LanguagePair) async {
        for index in items.indices {
            if let text = translations[items[index].original] { items[index].translation = text }
        }
        let finished = items.compactMap { item in translations[item.original].map { (item.original, $0) } }
        if isFrozen || stabilizer.isConfirmed || !current.reading.isContinuous {
            history.record(finished, pair: pair, source: .camera)
        } else {
            unconfirmed += finished
        }
        if !current.reading.isContinuous, !isFrozen, !items.contains(where: { $0.translation == nil }) {
            isTranslating = false
            updateReading()
        }
        // The first translation may have downloaded the languages.
        if readiness != .ready { await refreshReadiness() }
    }
}

private extension ReadingSettings.Speed {
    /// Vision reports 0.3, 0.5 or 1; lower ones are guesses.
    static let clearConfidence: Float = 0.5

    var interval: TimeInterval {
        switch self {
        case .balanced: 0.4
        case .fast: 0.15
        }
    }
}
