import AVFoundation
import CoreGraphics
import Foundation
@testable import GameTranslator

@MainActor
final class StubTranslator: TranslationProviding {
    var requests: [[String]] = []
    var translate: ([String]) async throws -> [String: String] = { texts in
        Dictionary(texts.map { ($0, "ar:\($0)") }) { first, _ in first }
    }

    func translations(for texts: [String], pair: LanguagePair) async throws -> [String: String] {
        requests.append(texts)
        return try await translate(texts)
    }
}

struct StubRecognizer: TextRecognizing {
    var texts: [String] = []
    var readableLanguages: Set<AppLanguage> = [.english]

    func recognizeText(in image: CGImage, language: AppLanguage) async throws -> [RecognizedLine] {
        texts.enumerated().map { index, text in
            RecognizedLine(text: text, boundingBox: CGRect(x: 0.1, y: 0.1 + 0.2 * Double(index), width: 0.5, height: 0.1))
        }
    }
}

@MainActor
final class StubPhotoLibrary: PhotoLibraryProviding {
    private(set) var saved: [Data] = []
    private let latest: Result<Data, AppError>
    private var saveError: AppError?

    init(latest: Result<Data, AppError> = .failure(.noScreenshot), saveError: AppError? = nil) {
        self.latest = latest
        self.saveError = saveError
    }

    @MainActor func latestScreenshotData() async throws -> Data { try latest.get() }

    @MainActor func save(_ imageData: Data) async throws {
        if let saveError {
            self.saveError = nil
            throw saveError
        }
        saved.append(imageData)
    }
}

final class InMemorySettingsStore: SettingsStoring {
    private var settings = AppSettings()

    func load() -> AppSettings { settings }
    func save(_ settings: AppSettings) { self.settings = settings }
}

struct StubCatalog: LanguageCatalogProviding {
    var languages: [AppLanguage] = []

    func translatableLanguages() async -> [AppLanguage] { languages }
}

@MainActor
final class StubLiveFeed: LiveFeed {
    var isAvailable = true
    var running = false
    var readableLanguages: Set<AppLanguage> = [.english]
    var capture: (any CaptureControlling)?
    var settingsChanges = 0
    func settingsDidChange() { settingsChanges += 1 }
    private var batches: [LiveBatch] = []
    private let session = UUID()
    private let stream = AsyncStream<Void>.makeStream()

    func push(_ lines: [String]) {
        batches.append(LiveBatch(sessionID: session, sequence: batches.count, date: .now, lines: lines))
    }

    func signal() { stream.continuation.yield() }
    func updates() -> AsyncStream<Void> { stream.stream }
    func isRunning() -> Bool { running }

    var currentControl = LiveControl()
    func control() -> LiveControl { currentControl }
    func setPaused(_ isPaused: Bool) { currentControl.isPaused = isPaused }

    func clear() {
        currentControl.generation += 1
        batches = []
    }

    func drain() -> [LiveBatch] {
        defer { batches = [] }
        return batches
    }
}

@MainActor
final class StubCapture: CaptureControlling {
    var starts = 0
    var stops = 0
    var error: AppError?

    func start() { starts += 1 }
    func stop() { stops += 1 }

    func takeError() -> AppError? {
        defer { error = nil }
        return error
    }
}

@MainActor
final class StubLiveActivity: LiveActivityControlling {
    var state: LiveActivityAttributes.ContentState?
    var flushes = 0

    func show(_ state: LiveActivityAttributes.ContentState) { self.state = state }
    func end() { state = nil }
    func flush() async { flushes += 1 }
}

@MainActor
final class StubNotifications: NotificationProviding {
    var isAllowed = true
    var shown: [String] = []

    func requestPermission() async -> Bool { isAllowed }
    func show(title: String, body: String) { shown.append(body) }
    func removeDelivered() { shown = [] }
}

final class StubKeyStore: KeyStoring, @unchecked Sendable {
    var key: String?
    var fails = false

    init(key: String? = nil) { self.key = key }

    func load() -> String? { key }
    func remove() { key = nil }

    func save(_ key: String) throws {
        if fails { throw AppError.keyNotSaved }
        self.key = key
    }
}

final class StubCloud: CloudTranslating, @unchecked Sendable {
    var error: AppError?
    private(set) var requests: [(texts: [String], key: String)] = []

    func translate(_ texts: [String], pair: LanguagePair, key: String) async throws -> [String: String] {
        requests.append((texts, key))
        if let error { throw error }
        return Dictionary(texts.map { ($0, "cloud:\($0)") }) { first, _ in first }
    }
}

@MainActor
final class StubCamera: CameraProviding {
    var session: AVCaptureSession? = AVCaptureSession()
    var hasTorch = true
    var isAllowed = true
    var regions: [CameraRegion] = []
    var torch = false
    var zoom: CGFloat = 1
    var isRunning = false
    var language: AppLanguage?
    private var continuation: AsyncStream<CameraEvent>.Continuation?

    func requestAccess() async -> Bool { isAllowed }

    func start(language: AppLanguage) -> AsyncStream<CameraEvent> {
        self.language = language
        isRunning = true
        let (stream, continuation) = AsyncStream<CameraEvent>.makeStream()
        self.continuation = continuation
        return stream
    }

    func stop() {
        isRunning = false
        continuation?.finish()
    }

    var isReading = false
    func setReading(_ isReading: Bool) { self.isReading = isReading }
    var interval: TimeInterval = 0
    func setInterval(_ interval: TimeInterval) { self.interval = interval }
    var isFrozen = false
    func setFrozen(_ isFrozen: Bool) { self.isFrozen = isFrozen }
    func setRegion(_ region: CameraRegion) { regions.append(region) }
    func setTorch(_ isOn: Bool) { torch = isOn }
    func setZoom(_ factor: CGFloat) { zoom = factor }

    /// The same text in as many frames.
    func see(_ texts: [String], frames: Int = 2, pixelHeight: CGFloat = 500, isStill: Bool = false, confidence: Float = 1) {
        for _ in 0..<frames {
            let lines = texts.enumerated().map { index, text in
                RecognizedLine(
                    text: text, boundingBox: CGRect(x: 0.1, y: 0.3 * Double(index), width: 0.5, height: 0.1),
                    confidence: confidence
                )
            }
            continuation?.yield(.reading(CameraReading(lines: lines, pixelHeight: pixelHeight, isStill: isStill)))
        }
    }

    func showStill(_ image: CGImage) { continuation?.yield(.still(image)) }
}

@MainActor
final class StubLanguages: LanguagePreparing {
    var readiness = LanguageReadiness.ready
    var prepared: [LanguagePair] = []
    var prepareError: (any Error)?

    func readiness(of pair: LanguagePair) async -> LanguageReadiness { readiness }

    func prepare(_ pair: LanguagePair) async throws {
        prepared.append(pair)
        if let prepareError { throw prepareError }
        readiness = .ready
    }
}

@MainActor
final class StubSpeaker: Speaking {
    var isSpeaking = false
    var spoken: [(text: String, language: AppLanguage)] = []

    func speak(_ text: String, language: AppLanguage) {
        spoken.append((text, language))
        isSpeaking = true
    }

    func stop() { isSpeaking = false }
}

@MainActor
final class StubHistory: HistoryRecording {
    var recorded: [(original: String, translation: String, source: HistoryEntry.Source)] = []

    func record(
        _ translations: [(original: String, translation: String)], pair: LanguagePair, source: HistoryEntry.Source
    ) {
        recorded += translations.map { ($0.original, $0.translation, source) }
    }
}

/// Polls because the work under test runs in its own task.
@MainActor
func eventually(_ condition: () -> Bool) async throws -> Bool {
    for _ in 0..<400 {
        if condition() { return true }
        try await Task.sleep(for: .milliseconds(25))
    }
    return condition()
}
