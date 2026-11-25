// Not part of the simulator SDK.
#if canImport(ScreenCaptureKit)
import Foundation

/// Experimental: captures the screen from the app itself (iOS 27+), so lines can be
/// translated while another app is in front instead of after coming back.
@available(iOS 27, *)
final class ScreenCaptureFeed: LiveFeed, CaptureControlling {
    let readableLanguages = OCRService(mode: .accurate).readableLanguages
    private let signals = LiveSignals()
    private var session: ScreenCaptureSession?
    private var worker: ScreenFrameWorker?
    private var batches: [LiveBatch] = []
    private var sessionID = UUID()
    private var sequence = 0
    private var running = false
    private var currentControl = LiveControl()
    private var error: AppError?

    // MARK: LiveFeed

    var isAvailable: Bool { ScreenCaptureSession.isAvailable }
    var capture: (any CaptureControlling)? { self }
    func updates() -> AsyncStream<Void> { signals.stream() }
    func isRunning() -> Bool { running }
    func control() -> LiveControl { currentControl }
    func settingsDidChange() {}

    func drain() -> [LiveBatch] {
        defer { batches = [] }
        return batches
    }

    func setPaused(_ isPaused: Bool) {
        currentControl.isPaused = isPaused
        worker?.setPaused(isPaused)
    }

    func clear() {
        currentControl.generation += 1
        batches = []
        worker?.reset()
    }

    // MARK: CaptureControlling

    func start() {
        guard !running else { return }
        error = nil
        let session = session ?? makeSession()
        self.session = session
        session.present()
    }

    func stop() { session?.stop() }

    func takeError() -> AppError? {
        defer { error = nil }
        return error
    }

    private func makeSession() -> ScreenCaptureSession {
        let worker = ScreenFrameWorker(recognize: ScreenFrameWorker.systemRecognize) {
            UserDefaultsSettingsStore().load().source
        } onLines: { [weak self] lines in
            Task { @MainActor in self?.receive(lines) }
        }
        self.worker = worker
        return ScreenCaptureSession(worker: worker) { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
    }

    private func receive(_ lines: [String]) {
        guard running else { return }
        sequence += 1
        batches.append(LiveBatch(sessionID: sessionID, sequence: sequence, date: .now, lines: lines))
        signals.send()
    }

    private func handle(_ event: ScreenCaptureSession.Event) {
        switch event {
        case .started:
            sessionID = UUID()
            currentControl.isPaused = false
            worker?.setPaused(false)
            worker?.reset()
            running = true
        case .stopped(let failure):
            running = false
            error = failure
        }
        signals.send()
    }
}
#endif
