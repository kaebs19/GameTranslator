import Foundation
import Observation

@Observable
final class CloudSettingsViewModel {
    var enteredKey = ""
    var error: AppError?
    private(set) var isEnabled: Bool
    private(set) var isChecking = false

    private let store: any SettingsStoring
    private let keys: any KeyStoring
    private let translator: any CloudTranslating

    init(store: any SettingsStoring, keys: any KeyStoring, translator: any CloudTranslating) {
        self.store = store
        self.keys = keys
        self.translator = translator
        isEnabled = store.load().usesCloudTranslation && keys.load() != nil
    }

    private var trimmedKey: String { enteredKey.trimmingCharacters(in: .whitespacesAndNewlines) }

    var canEnable: Bool { !isChecking && !trimmedKey.isEmpty }

    /// Called after the user agreed. Tries the key with a fixed word, never with game text.
    func enable() async {
        guard canEnable else { return }
        let key = trimmedKey
        isChecking = true
        defer { isChecking = false }
        do {
            _ = try await translator.translate(["Hello"], pair: LanguagePair(source: "en", target: "ar"), key: key)
            try keys.save(key)
            setEnabled(true)
            enteredKey = ""
        } catch {
            self.error = AppError(error)
        }
    }

    /// Also deletes the key, so turning it off leaves nothing behind.
    func disable() {
        keys.remove()
        setEnabled(false)
    }

    private func setEnabled(_ value: Bool) {
        var settings = store.load()
        settings.usesCloudTranslation = value
        store.save(settings)
        isEnabled = value
    }
}
