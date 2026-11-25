import Observation
import Translation

/// Translates text. View models depend on this, not on the Translation framework.
protocol TranslationProviding: AnyObject {
    /// Returns translations keyed by the original text.
    func translations(for texts: [String], pair: LanguagePair) async throws -> [String: String]
}

/// Cache first, then Apple's on-device translation, then the cloud if the user allowed it.
///
/// `TranslationSession` only exists inside SwiftUI, so missing texts wait in a queue until
/// a view with `.translationHost(_:)` supplies a session. While the app is in the background
/// no view can, so a headless session is used where the system has one (iOS 26+).
/// One service serves every screen.
@Observable
final class TranslationService: TranslationProviding, LanguagePreparing {
    typealias Translate = ([String]) async throws -> [String: String]
    typealias Prepare = () async throws -> Void
    /// Returns `nil` when this system cannot translate without a view.
    typealias HeadlessSession = (LanguagePair) -> Translate?

    /// Feeds `.translationTask`; changing it asks SwiftUI for a session.
    private(set) var configuration: TranslationSession.Configuration?

    private struct Job {
        let id: UUID
        /// Empty for a job that only prepares the languages.
        let texts: [String]
        let pair: LanguagePair
        let continuation: CheckedContinuation<[String: String], any Error>
    }

    @ObservationIgnored private var queue: [Job] = []
    @ObservationIgnored private var activePair: LanguagePair?
    @ObservationIgnored private var isDraining = false
    private let cache: TranslationCache
    private let isSupported: (LanguagePair) async -> Bool
    private let systemReadiness: (LanguagePair) async -> LanguageReadiness
    private let headlessSession: HeadlessSession
    private let cloud: CloudFallback?
    /// Whether a view can supply sessions, which also lets the system offer downloads.
    @ObservationIgnored private var isHostActive: Bool

    init(
        cache: TranslationCache,
        isSupported: @escaping (LanguagePair) async -> Bool = TranslationService.systemSupports,
        readiness: @escaping (LanguagePair) async -> LanguageReadiness = TranslationService.systemReadiness,
        isHostActive: Bool = false,
        headlessSession: @escaping HeadlessSession = TranslationService.systemHeadlessSession,
        cloud: CloudFallback? = nil
    ) {
        self.cache = cache
        self.isSupported = isSupported
        systemReadiness = readiness
        self.isHostActive = isHostActive
        self.headlessSession = headlessSession
        self.cloud = cloud
    }

    /// Always false in the simulator, where the Translation framework does not run.
    static func systemSupports(_ pair: LanguagePair) async -> Bool {
        await LanguageAvailability().status(from: pair.sourceLanguage, to: pair.targetLanguage) != .unsupported
    }

    static func systemReadiness(of pair: LanguagePair) async -> LanguageReadiness {
        LanguageReadiness(await LanguageAvailability().status(from: pair.sourceLanguage, to: pair.targetLanguage))
    }

    nonisolated static func systemHeadlessSession(_ pair: LanguagePair) -> Translate? {
        guard #available(iOS 26, *) else { return nil }
        return { try await HeadlessTranslation.translate($0, pair: pair) }
    }

    func translations(for texts: [String], pair: LanguagePair) async throws -> [String: String] {
        guard !pair.isSameLanguage else { throw AppError.sameLanguage }
        let cached = await cache.translations(for: texts, pair: pair)
        // Keep reading order so the engine sees sentences in context.
        var known = Set(cached.keys)
        let missing = texts.filter { known.insert($0).inserted }
        guard !missing.isEmpty else { return cached }
        let fresh = try await translateMissing(missing, pair: pair)
        return cached.merging(fresh) { _, new in new }
    }

    private func translateMissing(_ texts: [String], pair: LanguagePair) async throws -> [String: String] {
        do {
            return try await translateOnDevice(texts, pair: pair)
        } catch {
            guard !(error is CancellationError), let cloud,
                  let result = try await cloud.translate(texts, pair: pair) else { throw error }
            await cache.store(result, pair: pair)
            return result
        }
    }

    private func translateOnDevice(_ texts: [String], pair: LanguagePair) async throws -> [String: String] {
        guard await isSupported(pair) else { throw AppError.unsupportedLanguages }
        return isHostActive
            ? try await enqueue(texts, pair: pair)
            : try await translateHeadless(texts, pair: pair)
    }

    // MARK: Preparing

    func readiness(of pair: LanguagePair) async -> LanguageReadiness { await systemReadiness(pair) }

    func prepare(_ pair: LanguagePair) async throws {
        guard isHostActive else { throw AppError.translationNeedsApp }
        _ = try await enqueue([], pair: pair)
    }

    // MARK: Background

    func hostDidChange(isActive: Bool) {
        isHostActive = isActive
        if isActive {
            if !isDraining { requestSession() }
        } else {
            runQueueHeadless()
        }
    }

    private func translateHeadless(_ texts: [String], pair: LanguagePair) async throws -> [String: String] {
        guard let translate = headlessSession(pair) else { throw AppError.translationNeedsApp }
        let result = try await translate(texts)
        await cache.store(result, pair: pair)
        return result
    }

    /// Jobs still waiting for a view would otherwise block until the user comes back.
    private func runQueueHeadless() {
        let waiting = queue
        queue = []
        for job in waiting {
            Task {
                do {
                    guard !job.texts.isEmpty else { throw AppError.translationNeedsApp }
                    job.continuation.resume(returning: try await translateHeadless(job.texts, pair: job.pair))
                } catch {
                    job.continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: Queue

    private func enqueue(_ texts: [String], pair: LanguagePair) async throws -> [String: String] {
        let id = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                queue.append(Job(id: id, texts: texts, pair: pair, continuation: continuation))
                if !isDraining { requestSession() }
            }
        } onCancel: {
            Task { @MainActor in self.cancelQueuedJob(id) }
        }
    }

    /// A job that is already running is left to finish, so its result still reaches the cache.
    private func cancelQueuedJob(_ id: UUID) {
        guard let index = queue.firstIndex(where: { $0.id == id }) else { return }
        queue.remove(at: index).continuation.resume(throwing: CancellationError())
    }

    private func requestSession() {
        guard let pair = queue.first?.pair else { return }
        if activePair == pair, configuration != nil {
            configuration?.invalidate()
        } else {
            activePair = pair
            configuration = .init(source: pair.sourceLanguage, target: pair.targetLanguage)
        }
    }

    /// Called by the translation host with a live session.
    func drainQueue(using translate: Translate, prepare: Prepare = {}) async {
        guard !isDraining else { return }
        isDraining = true
        while !Task.isCancelled, let job = takeJobForActivePair() {
            await run(job, using: translate, prepare: prepare)
        }
        isDraining = false
        // Left over: another language pair, or this session was cancelled midway.
        requestSession()
    }

    private func takeJobForActivePair() -> Job? {
        guard let first = queue.first, first.pair == activePair else { return nil }
        return queue.removeFirst()
    }

    private func run(_ job: Job, using translate: Translate, prepare: Prepare) async {
        do {
            guard !job.texts.isEmpty else {
                try await prepare()
                return job.continuation.resume(returning: [:])
            }
            let result = try await translate(job.texts)
            await cache.store(result, pair: job.pair)
            job.continuation.resume(returning: result)
        } catch {
            job.continuation.resume(throwing: error)
        }
    }
}
