import Foundation
import Testing
@testable import GameTranslator

@MainActor
struct LiveViewModelTests {
    private let feed = StubLiveFeed()
    private let translator = StubTranslator()
    private let settings = InMemorySettingsStore()
    private let activity = StubLiveActivity()
    private let notifications = StubNotifications()
    private let history = StubHistory()

    private func makeViewModel(feed: (any LiveFeed)? = nil, isAppActive: Bool = true) -> LiveViewModel {
        LiveViewModel(
            feed: feed ?? self.feed, translator: translator, settings: settings, activity: activity,
            notifications: notifications, history: history, isAppActive: { isAppActive }
        )
    }

    private func change(_ body: (inout AppSettings) -> Void) {
        var current = settings.load()
        body(&current)
        settings.save(current)
    }

    private func translations(_ viewModel: LiveViewModel) -> [String?] { viewModel.lines.map(\.translation) }

    @Test func showsAndTranslatesNewLines() async throws {
        let viewModel = makeViewModel()
        feed.running = true
        feed.push(["Follow the car"])
        viewModel.refresh()
        #expect(viewModel.isRunning)
        #expect(viewModel.lines.map(\.original) == ["Follow the car"])
        #expect(try await eventually { translations(viewModel) == ["ar:Follow the car"] })
    }

    @Test func observesTheFeedUntilCancelled() async throws {
        let viewModel = makeViewModel()
        let task = Task { await viewModel.observeFeed() }
        feed.push(["Follow the car"])
        feed.signal()
        #expect(try await eventually { translations(viewModel) == ["ar:Follow the car"] })
        task.cancel()
    }

    @Test func longBacklogIsTranslatedInParts() async throws {
        let viewModel = makeViewModel()
        feed.push((1...45).map { "Line number \($0) of the story" })
        viewModel.refresh()
        #expect(try await eventually { !translations(viewModel).contains(nil) })
        #expect(translator.requests.map(\.count) == [20, 20, 5])
    }

    @Test func linesArrivingDuringTranslationAreNotLost() async throws {
        let viewModel = makeViewModel()
        var release: CheckedContinuation<Void, Never>?
        translator.translate = { texts in
            if release == nil { await withCheckedContinuation { release = $0 } }
            return Dictionary(texts.map { ($0, "ar") }) { first, _ in first }
        }
        feed.push(["Follow the car"])
        viewModel.refresh()
        #expect(try await eventually { release != nil })
        feed.push(["Lose the police"])
        viewModel.refresh()
        release?.resume()
        #expect(try await eventually { translations(viewModel) == ["ar", "ar"] })
    }

    @Test func missingTranslationFallsBackToTheOriginal() async throws {
        let viewModel = makeViewModel()
        translator.translate = { _ in [:] }
        feed.push(["Follow the car"])
        viewModel.refresh()
        #expect(try await eventually { translations(viewModel) == ["Follow the car"] })
    }

    @Test func failureKeepsLinesAndReturningToTheAppRetries() async throws {
        let viewModel = makeViewModel()
        let working = translator.translate
        translator.translate = { _ in throw AppError.unsupportedLanguages }
        feed.push(["Follow the car"])
        viewModel.refresh()
        #expect(try await eventually { viewModel.translationError == .unsupportedLanguages })
        #expect(viewModel.lines.count == 1)
        // Let the failed task clear itself before asking again.
        try await Task.sleep(for: .milliseconds(50))
        translator.translate = working
        viewModel.appDidBecomeActive()
        #expect(try await eventually { translations(viewModel) == ["ar:Follow the car"] })
        #expect(viewModel.translationError == nil)
    }

    @Test func explainsWhyABroadcastCannotWork() {
        #expect(makeViewModel().setupError == nil)
        settings.save(AppSettings(source: AppLanguage(code: "ja"), target: .arabic))
        let viewModel = makeViewModel()
        #expect(viewModel.setupError == .liveLanguageUnsupported)
        settings.save(AppSettings(source: .english, target: .english))
        viewModel.settingsDidClose()
        #expect(viewModel.setupError == .sameLanguage)
        feed.isAvailable = false
        viewModel.settingsDidClose()
        #expect(viewModel.setupError == .appGroupUnavailable)
    }

    /// Frame → OCR → App Group files → feed → transcript → translation.
    @Test func wholePipelineWithoutTheBroadcast() async throws {
        let channel = LiveChannel(
            directory: FileManager.default.temporaryDirectory.appending(path: "live-\(UUID().uuidString)")
        )
        let recognizer = OCRService(mode: .fast)
        let processor = LiveFrameProcessor { try recognizer.recognize($0, orientation: $1, language: $2) }
        let session = UUID()
        for (index, lines) in [["Follow the car"], ["Follow the car", "Lose the police"]].enumerated() {
            let outcome = try processor.process(TestImage.luma(lines: lines), orientation: .up, language: .english)
            guard case .newLines(let new) = outcome else { continue }
            try channel.send(LiveBatch(sessionID: session, sequence: index, date: .now, lines: new))
        }
        try channel.write(LiveStatus(sessionID: session, isRunning: true, heartbeat: .now))
        let viewModel = makeViewModel(feed: AppGroupLiveFeed(channel: channel))
        viewModel.refresh()
        #expect(viewModel.isRunning)
        #expect(try await eventually { translations(viewModel) == ["ar:Follow the car", "ar:Lose the police"] })
    }

    // MARK: Live Activity

    @Test func activityShowsLatestTranslationsUpToTheSetting() async throws {
        change { $0.live.lineCount = 2 }
        let viewModel = makeViewModel()
        feed.running = true
        feed.push(["Follow the car", "Lose the police", "Return home now"])
        viewModel.refresh()
        #expect(activity.state?.pendingCount == 3)
        #expect(try await eventually { activity.state?.pendingCount == 0 })
        #expect(activity.state?.lines == ["ar:Lose the police", "ar:Return home now"])
    }

    @Test func activityEndsWithTheBroadcastOrTheSetting() {
        let viewModel = makeViewModel()
        feed.running = true
        viewModel.refresh()
        #expect(activity.state != nil)
        change { $0.live.showsLiveActivity = false }
        viewModel.settingsDidClose()
        #expect(activity.state == nil)
        change { $0.live.showsLiveActivity = true }
        viewModel.settingsDidClose()
        #expect(activity.state != nil)
        feed.running = false
        viewModel.refresh()
        #expect(activity.state == nil)
    }

    @Test func translateNowFinishesWithTheResultShown() async {
        let viewModel = makeViewModel(isAppActive: false)
        feed.running = true
        feed.push(["Follow the car"])
        await viewModel.translateNow()
        #expect(activity.state?.lines == ["ar:Follow the car"])
        #expect(activity.flushes == 1)
        #expect(history.recorded.map(\.translation) == ["ar:Follow the car"])
        #expect(history.recorded.first?.source == .live)
    }

    @Test func activityAsksForTheAppWhenBackgroundTranslationFails() async {
        translator.translate = { _ in throw AppError.translationNeedsApp }
        let viewModel = makeViewModel(isAppActive: false)
        feed.running = true
        feed.push(["Follow the car"])
        await viewModel.translateNow()
        #expect(activity.state?.needsApp == true)
        #expect(activity.state?.pendingCount == 1)
    }

    // MARK: Pause and clear

    @Test func pauseReachesTheFeedAndTheActivity() async {
        let viewModel = makeViewModel()
        feed.running = true
        viewModel.refresh()
        await viewModel.togglePause()
        #expect(feed.currentControl.isPaused && viewModel.isPaused)
        #expect(activity.state?.isPaused == true)
        await viewModel.togglePause()
        #expect(!feed.currentControl.isPaused && !viewModel.isPaused)
    }

    @Test func clearForgetsTextSoItCanAppearAgain() async throws {
        let viewModel = makeViewModel()
        feed.running = true
        feed.push(["Follow the car"])
        viewModel.refresh()
        #expect(try await eventually { translations(viewModel) == ["ar:Follow the car"] })
        await viewModel.clear()
        #expect(viewModel.lines.isEmpty)
        #expect(activity.state?.lines.isEmpty == true)
        #expect(feed.currentControl.generation == 1)
        feed.push(["Follow the car"])
        viewModel.refresh()
        #expect(try await eventually { translations(viewModel) == ["ar:Follow the car"] })
    }

    @Test func clearDuringTranslationDropsItsResultAndContinues() async throws {
        let viewModel = makeViewModel()
        var release: CheckedContinuation<Void, Never>?
        translator.translate = { texts in
            if release == nil { await withCheckedContinuation { release = $0 } }
            return Dictionary(texts.map { ($0, "ar") }) { first, _ in first }
        }
        feed.push(["Follow the car"])
        viewModel.refresh()
        #expect(try await eventually { release != nil })
        await viewModel.clear()
        feed.push(["Lose the police"])
        viewModel.refresh()
        release?.resume()
        #expect(try await eventually { translations(viewModel) == ["ar"] })
        #expect(viewModel.lines.map(\.original) == ["Lose the police"])
        #expect(viewModel.translationError == nil)
    }

    // MARK: Notifications

    @Test func notifiesWithTranslationsOnlyInBackgroundAndWhenEnabled() async {
        for (enabled, active, expected) in [(true, false, 1), (true, true, 0), (false, false, 0)] {
            change { $0.live.sendsNotifications = enabled }
            notifications.shown = []
            let viewModel = makeViewModel(isAppActive: active)
            feed.push(["Follow the car"])
            await viewModel.translateNow()
            #expect(notifications.shown == Array(repeating: "ar:Follow the car", count: expected))
        }
    }

    @Test func openingTheAppRemovesTheBanner() {
        notifications.shown = ["old"]
        makeViewModel().appDidBecomeActive()
        #expect(notifications.shown.isEmpty)
    }

    // MARK: In-app capture

    @Test func inAppCaptureIsStartedAndStoppedByTheApp() {
        #expect(!makeViewModel().capturesInApp)
        let capture = StubCapture()
        feed.capture = capture
        let viewModel = makeViewModel()
        #expect(viewModel.capturesInApp)
        viewModel.startCapture()
        viewModel.stopCapture()
        #expect(capture.starts == 1 && capture.stops == 1)
    }

    @Test func captureErrorIsShownUntilTheNextStart() {
        let capture = StubCapture()
        feed.capture = capture
        let viewModel = makeViewModel()
        capture.error = .captureFailed("x")
        viewModel.refresh()
        viewModel.refresh()
        #expect(viewModel.captureError == .captureFailed("x"))
        viewModel.startCapture()
        #expect(viewModel.captureError == nil)
    }

    @Test func backgroundBannersAreThrottled() async {
        change { $0.live.sendsNotifications = true }
        let viewModel = makeViewModel(isAppActive: false)
        for text in ["Follow the car", "Lose the police", "Return home now"] {
            feed.push([text])
            await viewModel.translateNow()
        }
        #expect(notifications.shown == ["ar:Follow the car"])
    }

    @Test func switchingFeedFollowsTheSetting() async throws {
        let inApp = StubLiveFeed()
        let capture = StubCapture()
        inApp.capture = capture
        inApp.readableLanguages = [AppLanguage(code: "ja")]
        let switching = SwitchingLiveFeed(broadcast: feed, inApp: inApp, settings: settings)
        feed.push(["Broadcast line"])
        inApp.push(["Captured line"])
        #expect(switching.drain().flatMap(\.lines) == ["Broadcast line"])
        #expect(switching.capture == nil)
        change { $0.live.usesScreenCapture = true }
        switching.settingsDidChange()
        #expect(capture.stops == 0)
        #expect(switching.drain().flatMap(\.lines) == ["Captured line"])
        #expect(switching.readableLanguages == [AppLanguage(code: "ja")])
        change { $0.live.usesScreenCapture = false }
        switching.settingsDidChange()
        #expect(capture.stops == 1)
    }

    @Test func switchingFeedForwardsSignalsFromBoth() async throws {
        let inApp = StubLiveFeed()
        let switching = SwitchingLiveFeed(broadcast: feed, inApp: inApp, settings: settings)
        var iterator = switching.updates().makeAsyncIterator()
        inApp.signal()
        #expect(await iterator.next() != nil)
        feed.signal()
        #expect(await iterator.next() != nil)
    }

    @Test func observingStartsOnlyOnce() async throws {
        let viewModel = makeViewModel()
        viewModel.startObserving()
        viewModel.startObserving()
        feed.push(["Follow the car"])
        feed.signal()
        #expect(try await eventually { translations(viewModel) == ["ar:Follow the car"] })
    }
}
