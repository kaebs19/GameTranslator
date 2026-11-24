import CoreGraphics
import Observation
import Translation
import UIKit

/// Drives image → OCR → cache lookup → translation → rendered image.
@Observable
final class InstantTranslateModel {
    enum Phase: Equatable {
        case idle, loading, recognizing, translating, finished
        case failed(TranslateFailure)

        var isBusy: Bool { self == .loading || self == .recognizing || self == .translating }
    }

    struct Row: Identifiable {
        let id: UUID
        let original: String
        let translation: String?
    }

    private(set) var phase: Phase = .idle
    private(set) var originalImage: CGImage?
    private(set) var translatedImage: UIImage?
    private(set) var rows: [Row] = []
    /// Feeds `.translationTask`; changing it starts a translation.
    private(set) var configuration: TranslationSession.Configuration?

    private struct Job {
        let id: UUID
        let texts: [String]
    }

    @ObservationIgnored private var lines: [RecognizedLine] = []
    @ObservationIgnored private var translations: [String: String] = [:]
    @ObservationIgnored private var settings = AppSettings.current
    @ObservationIgnored private var pendingJob: Job?
    @ObservationIgnored private var work: Task<Void, Never>?
    /// Identifies the latest request so results of an older one are dropped.
    @ObservationIgnored private var runID = UUID()
    private let cache: TranslationCache
    private let isSupported: (LanguagePair) async -> Bool

    init(
        cache: TranslationCache = .shared,
        isSupported: @escaping (LanguagePair) async -> Bool = InstantTranslateModel.systemSupports
    ) {
        self.cache = cache
        self.isSupported = isSupported
    }

    /// Always false in the simulator, where the Translation framework does not run.
    static func systemSupports(_ pair: LanguagePair) async -> Bool {
        await LanguageAvailability().status(
            from: Locale.Language(identifier: pair.source),
            to: Locale.Language(identifier: pair.target)
        ) != .unsupported
    }

    // MARK: Entry points

    func translateLatestScreenshot() {
        start { try await PhotoLibrary.latestScreenshotData() }
    }

    func translate(_ loadData: @escaping () async throws -> Data?) {
        start {
            guard let data = try await loadData() else { throw TranslateFailure.unreadableImage }
            return data
        }
    }

    /// Runs again on the current image, for example after a language change.
    func retry() {
        guard let originalImage else { return }
        beginRun { [weak self] run in
            try await self?.process(originalImage, run: run)
        }
    }

    func retranslateIfSettingsChanged() {
        if originalImage != nil, settings != AppSettings.current { retry() }
    }

    func reset() {
        work?.cancel()
        runID = UUID()
        pendingJob = nil
        originalImage = nil
        clearResult()
        phase = .idle
    }

    // MARK: Pipeline

    private func start(_ loadData: @escaping () async throws -> Data) {
        originalImage = nil
        beginRun { [weak self] run in
            let image = try await ImageLoader.decode(try await loadData())
            guard let self, run == self.runID else { return }
            self.originalImage = image
            try await self.process(image, run: run)
        }
    }

    private func beginRun(_ body: @escaping (UUID) async throws -> Void) {
        work?.cancel()
        let run = UUID()
        runID = run
        pendingJob = nil
        clearResult()
        phase = .loading
        work = Task { [weak self] in
            do {
                try await body(run)
            } catch {
                self?.fail(error, run: run)
            }
        }
    }

    private func clearResult() {
        lines = []
        rows = []
        translations = [:]
        translatedImage = nil
    }

    private func process(_ image: CGImage, run: UUID) async throws {
        settings = .current
        guard settings.source.rawValue != settings.target.rawValue else { throw TranslateFailure.sameLanguage }
        phase = .recognizing
        let ocr = OCRService(mode: .accurate, languages: [settings.source.visionCode])
        let recognized = try await ocr.recognizeText(in: image)
        guard run == runID else { return }
        lines = recognized.filter { TextNormalizer.isTranslatable($0.text) }
        guard !lines.isEmpty else { throw TranslateFailure.noText }
        try await translateLines(run: run)
    }

    private func translateLines(run: UUID) async throws {
        let unique = Set(lines.map(\.text))
        let cached = await cache.translations(for: Array(unique), pair: settings.pair)
        guard run == runID else { return }
        translations = cached
        updateRows()
        // Keep reading order so the engine sees sentences in context.
        var queued = Set(cached.keys)
        let missing = lines.map(\.text).filter { queued.insert($0).inserted }
        guard !missing.isEmpty else { return await finish(run: run) }

        guard await isSupported(settings.pair) else { throw TranslateFailure.unsupportedLanguages }
        guard run == runID else { return }
        phase = .translating
        pendingJob = Job(id: run, texts: missing)
        requestTranslationSession()
    }

    private func requestTranslationSession() {
        let source = Locale.Language(identifier: settings.source.rawValue)
        let target = Locale.Language(identifier: settings.target.rawValue)
        if configuration?.source == source, configuration?.target == target {
            configuration?.invalidate()
        } else {
            configuration = .init(source: source, target: target)
        }
    }

    /// Called from `.translationTask` with a live session.
    func runPendingJob(with translate: ([String]) async throws -> [String: String]) async {
        guard let job = pendingJob else { return }
        pendingJob = nil
        do {
            let result = try await translate(job.texts)
            await cache.store(result, pair: settings.pair)
            guard job.id == runID else { return }
            translations.merge(result) { _, new in new }
            updateRows()
            await finish(run: job.id)
        } catch {
            fail(error, run: job.id)
        }
    }

    private func finish(run: UUID) async {
        guard let image = originalImage else { return }
        let overlays = lines.compactMap { line in
            translations[line.text].map { TextOverlay(text: $0, boundingBox: line.boundingBox) }
        }
        let isRTL = Locale.Language(identifier: settings.target.rawValue).characterDirection == .rightToLeft
        let rendered = await ImageTranslationRenderer(isRightToLeft: isRTL).render(image, overlays: overlays)
        guard run == runID else { return }
        translatedImage = rendered.map { UIImage(cgImage: $0) }
        phase = .finished
    }

    private func updateRows() {
        rows = lines.map { Row(id: $0.id, original: $0.text, translation: translations[$0.text]) }
    }

    private func fail(_ error: any Error, run: UUID) {
        guard run == runID else { return }
        if let failure = error as? TranslateFailure {
            phase = .failed(failure)
        } else {
            phase = .failed(.translationFailed(error.localizedDescription))
        }
    }
}
