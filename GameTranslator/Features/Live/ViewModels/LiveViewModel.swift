import Foundation
import Observation

/// Collects lines from the feed and translates them while the app can run.
@Observable
final class LiveViewModel {
    private(set) var transcript = LiveTranscript()
    private(set) var isRunning = false
    private(set) var isPaused = false
    /// The app starts capture itself instead of showing the system broadcast button.
    private(set) var capturesInApp = false
    /// Decides which privacy note is true.
    private(set) var usesCloud = false
    private(set) var captureError: AppError?
    private(set) var translationError: AppError?
    /// Why a broadcast cannot work right now.
    private(set) var setupError: AppError?

    private let feed: any LiveFeed
    private let translator: any TranslationProviding
    private let settings: any SettingsStoring
    private let activity: any LiveActivityControlling
    private let notifications: any NotificationProviding
    private let history: any HistoryRecording
    private let isAppActive: () -> Bool
    @ObservationIgnored private var observation: Task<Void, Never>?
    @ObservationIgnored private var bannerThrottle = NotificationThrottle()
    @ObservationIgnored private var translation: Task<Void, Never>?

    /// Small batches show the first results sooner after a long session.
    private static let translationBatch = 20

    init(
        feed: any LiveFeed, translator: any TranslationProviding,
        settings: any SettingsStoring, activity: any LiveActivityControlling,
        notifications: any NotificationProviding, history: any HistoryRecording,
        isAppActive: @escaping () -> Bool
    ) {
        self.feed = feed
        self.translator = translator
        self.settings = settings
        self.activity = activity
        self.notifications = notifications
        self.history = history
        self.isAppActive = isAppActive
        checkSetup()
    }

    var lines: [LiveTranscript.Line] { transcript.lines }

    /// Not tied to a view: in-app capture goes on while no view is on screen.
    func startObserving() {
        guard observation == nil else { return }
        observation = Task { [weak self] in await self?.observeFeed() }
    }

    func startCapture() {
        captureError = nil
        feed.capture?.start()
    }

    func stopCapture() { feed.capture?.stop() }

    /// Runs until the calling task is cancelled.
    func observeFeed() async {
        for await _ in feed.updates() { refresh() }
    }

    func refresh() {
        let running = feed.isRunning()
        if isRunning != running { isRunning = running }
        if let error = feed.capture?.takeError() { captureError = error }
        let paused = feed.control().isPaused
        if isPaused != paused { isPaused = paused }
        let batches = feed.drain()
        for batch in batches { transcript.append(batch) }
        if !batches.isEmpty { translatePending() }
        updateActivity()
    }

    /// A translation interrupted by leaving the app is resumed without asking.
    func appDidBecomeActive() {
        notifications.removeDelivered()
        refresh()
        retryTranslation()
    }

    func settingsDidClose() {
        feed.settingsDidChange()
        captureError = nil
        checkSetup()
        retryTranslation()
        updateActivity()
    }

    func retryTranslation() {
        translationError = nil
        translatePending()
    }

    private func setPaused(_ paused: Bool) {
        feed.setPaused(paused)
        isPaused = paused
        updateActivity()
    }

    private func clearTranscript() {
        translation?.cancel()
        feed.clear()
        transcript.clear()
        translationError = nil
        updateActivity()
    }

    // MARK: Outside the app

    private func updateActivity() {
        let live = settings.load().live
        guard isRunning, live.showsLiveActivity else { return activity.end() }
        activity.show(LiveActivityAttributes.ContentState(
            lines: transcript.latestTranslations(live.lineCount),
            pendingCount: transcript.untranslated.count,
            isPaused: isPaused,
            needsApp: translationError != nil,
            updated: .now
        ))
    }

    /// Replaces the extension's "new text" banner with the translation itself.
    private func notifyIfInBackground(_ translated: [String]) {
        let live = settings.load().live
        guard live.sendsNotifications, !isAppActive(), !translated.isEmpty,
              bannerThrottle.allows(at: ProcessInfo.processInfo.systemUptime) else { return }
        notifications.show(
            title: String(localized: .liveNotificationTitle),
            body: translated.suffix(live.lineCount).joined(separator: "\n")
        )
    }

    // MARK: Translation

    private func checkSetup() {
        let current = settings.load()
        capturesInApp = feed.capture != nil
        usesCloud = current.usesCloudTranslation
        if !feed.isAvailable {
            setupError = .appGroupUnavailable
        } else if current.pair.isSameLanguage {
            setupError = .sameLanguage
        } else if !feed.readableLanguages.contains(current.source) {
            setupError = .liveLanguageUnsupported
        } else {
            setupError = nil
        }
    }

    /// One loop at a time; lines that arrive meanwhile are picked up by its next round.
    private func translatePending() {
        guard translation == nil, translationError == nil, !transcript.untranslated.isEmpty else { return }
        translation = Task { [weak self] in
            await self?.translateUntilDone()
            guard let self else { return }
            translation = nil
            updateActivity()
            // A cancelled run may have left newer lines behind.
            if Task.isCancelled { translatePending() }
        }
    }

    private func translateUntilDone() async {
        while !Task.isCancelled {
            let texts = Array(transcript.untranslated.prefix(Self.translationBatch))
            guard !texts.isEmpty else { return }
            do {
                let pair = settings.load().pair
                let result = try await translator.translations(for: texts, pair: pair)
                // Without an entry for every text this loop would never end.
                let complete = Dictionary(texts.map { ($0, result[$0] ?? $0) }) { first, _ in first }
                guard !Task.isCancelled else { return }
                transcript.apply(complete)
                history.record(
                    texts.compactMap { text in result[text].map { (text, $0) } }, pair: pair, source: .live
                )
                updateActivity()
                notifyIfInBackground(texts.compactMap { complete[$0] })
            } catch {
                guard !Task.isCancelled else { return }
                translationError = AppError(error)
                return
            }
        }
    }
}

extension LiveViewModel: LiveActionHandling {
    /// Finishes only when the result is on screen, because iOS suspends the app right after.
    func translateNow() async {
        refresh()
        retryTranslation()
        await translation?.value
        await activity.flush()
    }

    func togglePause() async {
        setPaused(!feed.control().isPaused)
        await activity.flush()
    }

    func clear() async {
        // Launched in the background by the button, nothing has been read yet.
        refresh()
        clearTranscript()
        await activity.flush()
    }
}
