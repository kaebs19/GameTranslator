import CoreGraphics
import Foundation
import Observation
import UIKit

/// Drives image → OCR → translation → rendered image.
@Observable
final class InstantTranslateViewModel {
    enum State {
        case idle, loading, recognizing, translating
        case finished(TranslationResult)
        case failed(AppError)
    }

    private(set) var state: State = .idle
    private var image: CGImage?

    private let translator: any TranslationProviding
    private let recognizer: any TextRecognizing
    private let photos: any PhotoLibraryProviding
    private let settings: any SettingsStoring
    private let history: any HistoryRecording
    @ObservationIgnored private var usedSettings: AppSettings?
    @ObservationIgnored private var work: Task<Void, Never>?

    init(
        translator: any TranslationProviding,
        recognizer: any TextRecognizing,
        photos: any PhotoLibraryProviding,
        settings: any SettingsStoring,
        history: any HistoryRecording
    ) {
        self.translator = translator
        self.recognizer = recognizer
        self.photos = photos
        self.settings = settings
        self.history = history
    }

    var isIdle: Bool {
        if case .idle = state { true } else { false }
    }

    var canRetry: Bool { image != nil }

    // MARK: Actions

    func handle(_ request: AppRouter.Request) {
        switch request {
        case .latestScreenshot: translateLatestScreenshot()
        case .image(let data): translate { data }
        case .live: break
        }
    }

    func translateLatestScreenshot() {
        translate { [photos] in try await photos.latestScreenshotData() }
    }

    func translate(_ loadData: @escaping () async throws -> Data?) {
        image = nil
        startWork { viewModel in
            guard let data = try await loadData() else { throw AppError.unreadableImage }
            let decoded = try await ImageLoader.decode(data)
            try Task.checkCancellation()
            viewModel.image = decoded
            try await viewModel.process(decoded)
        }
    }

    func retry() {
        guard let image else { return }
        startWork { try await $0.process(image) }
    }

    func settingsDidClose() {
        guard image != nil, !settings.load().translatesLike(usedSettings) else { return }
        retry()
    }

    func reset() {
        work?.cancel()
        image = nil
        state = .idle
    }

    // MARK: Pipeline

    /// Only the newest task may change state: older ones are cancelled and then ignored.
    private func startWork(_ body: @escaping (InstantTranslateViewModel) async throws -> Void) {
        work?.cancel()
        state = .loading
        work = Task { [weak self] in
            guard let self else { return }
            do {
                try await body(self)
            } catch {
                guard !Task.isCancelled else { return }
                state = .failed(AppError(error))
            }
        }
    }

    private func process(_ image: CGImage) async throws {
        let current = settings.load()
        usedSettings = current
        guard !current.pair.isSameLanguage else { throw AppError.sameLanguage }

        state = .recognizing
        let recognized = try await recognizer.recognizeText(in: image, language: current.source)
        try Task.checkCancellation()
        let lines = recognized.filter { TextNormalizer.isTranslatable($0.text) }
        let blocks = LineMerger.blocks(from: lines, aspectRatio: CGFloat(image.width) / CGFloat(image.height))
        guard !blocks.isEmpty else { throw AppError.noText }

        state = .translating
        let translations = try await translator.translations(for: blocks.map(\.text), pair: current.pair)
        try Task.checkCancellation()

        let result = try await makeResult(image: image, blocks: blocks, translations: translations, pair: current.pair)
        try Task.checkCancellation()
        history.record(
            result.rows.compactMap { row in row.translation.map { (row.original, $0) } },
            pair: current.pair, source: .photo
        )
        state = .finished(result)
    }

    private func makeResult(
        image: CGImage, blocks: [TextBlock], translations: [String: String], pair: LanguagePair
    ) async throws -> TranslationResult {
        let overlays = blocks.compactMap { block in
            translations[block.text].map {
                TextOverlay(text: $0, boundingBox: block.boundingBox, lineHeight: block.lineHeight)
            }
        }
        let renderer = ImageTranslationRenderer(isRightToLeft: pair.isTargetRightToLeft)
        guard let rendered = await renderer.render(image, overlays: overlays) else { throw AppError.unreadableImage }
        return TranslationResult(
            image: UIImage(cgImage: rendered),
            rows: blocks.map { .init(id: $0.id, original: $0.text, translation: translations[$0.text]) },
            pair: pair
        )
    }
}
