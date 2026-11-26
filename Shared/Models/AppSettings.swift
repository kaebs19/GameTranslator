import Foundation

nonisolated struct AppSettings: Equatable, Sendable {
    /// Choosing the language the other side already has swaps the two.
    var source: AppLanguage {
        didSet {
            add(source)
            if source == target, source != oldValue { target = oldValue }
        }
    }
    var target: AppLanguage {
        didSet {
            add(target)
            if target == source, target != oldValue { source = oldValue }
        }
    }
    /// Languages offered in the pickers. Always holds `source` and `target`.
    private(set) var languages: [AppLanguage]
    var live = LiveSettings()
    var reading = ReadingSettings()
    var tv = TVSettings()
    var server = ServerSettings()
    var remotePlay = RemotePlaySettings()
    /// Off by default: nothing leaves the device unless the user turns this on.
    var usesCloudTranslation = false

    init(
        source: AppLanguage = .english, target: AppLanguage = .arabic,
        languages: [AppLanguage] = AppLanguage.defaults
    ) {
        self.source = source
        self.target = target
        self.languages = []
        for language in languages + [source, target] { add(language) }
    }

    var pair: LanguagePair { LanguagePair(source: source.code, target: target.code) }

    /// What a finished translation depends on; the language list is not part of it.
    func translatesLike(_ other: AppSettings?) -> Bool { pair == other?.pair }

    mutating func add(_ language: AppLanguage) {
        if !languages.contains(language) { languages.append(language) }
    }

    /// Languages in use stay, so the pickers never point at something missing.
    mutating func remove(_ language: AppLanguage) {
        guard canRemove(language) else { return }
        languages.removeAll { $0 == language }
    }

    func canRemove(_ language: AppLanguage) -> Bool {
        language != source && language != target
    }
}
