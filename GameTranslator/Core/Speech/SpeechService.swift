import AVFoundation
import Observation

protocol Speaking: AnyObject {
    var isSpeaking: Bool { get }
    func speak(_ text: String, language: AppLanguage)
    func stop()
}

/// Reads translations aloud with the system voice, on the device.
@Observable
final class SystemSpeaker: NSObject, Speaking {
    private(set) var isSpeaking = false
    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        // Lets the system mix it with the game's sound instead of stopping it.
        synthesizer.usesApplicationAudioSession = false
        synthesizer.delegate = self
    }

    func speak(_ text: String, language: AppLanguage) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language.code)
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() { synthesizer.stopSpeaking(at: .immediate) }

    private func finished(stillSpeaking: Bool) { isSpeaking = stillSpeaking }
}

extension SystemSpeaker: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let stillSpeaking = synthesizer.isSpeaking
        Task { @MainActor in self.finished(stillSpeaking: stillSpeaking) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let stillSpeaking = synthesizer.isSpeaking
        Task { @MainActor in self.finished(stillSpeaking: stillSpeaking) }
    }
}
