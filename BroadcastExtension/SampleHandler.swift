import CoreMedia
import ReplayKit

/// Entry point the system starts when the user begins a broadcast.
/// `@unchecked`: ReplayKit calls it on its own queue and `LiveSession` does its own locking.
final class SampleHandler: RPBroadcastSampleHandler, @unchecked Sendable {
    private var session: LiveSession?

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        guard let channel = LiveChannel.appGroup() else { return stop(.errorAppGroup) }
        let language = UserDefaultsSettingsStore().load().source
        let recognizer = OCRService(mode: .fast)
        guard recognizer.readableLanguages.contains(language) else { return stop(.errorLanguage) }
        session = LiveSession(channel: channel, recognizer: recognizer)
        session?.start()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }
        session?.handle(sampleBuffer)
    }

    override func broadcastFinished() {
        session?.finish()
        session = nil
    }

    private func stop(_ message: LocalizedStringResource) {
        finishBroadcastWithError(NSError(
            domain: "BroadcastExtension", code: 1,
            userInfo: [NSLocalizedDescriptionKey: String(localized: message)]
        ))
    }
}
