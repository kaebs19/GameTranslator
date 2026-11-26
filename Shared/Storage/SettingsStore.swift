import Foundation

nonisolated protocol SettingsStoring {
    func load() -> AppSettings
    func save(_ settings: AppSettings)
}

/// Keeps settings in the App Group so the broadcast extension can read them later.
nonisolated struct UserDefaultsSettingsStore: SettingsStoring {
    private enum Key {
        static let source = "sourceLanguage"
        static let target = "targetLanguage"
        static let languages = "languages"
        static let showsLiveActivity = "live.showsActivity"
        static let sendsNotifications = "live.sendsNotifications"
        static let usesScreenCapture = "live.usesScreenCapture"
        static let isContinuous = "reading.isContinuous"
        static let showsOriginal = "reading.showsOriginal"
        static let speed = "reading.speed"
        static let textSize = "reading.textSize"
        static let savesHistory = "reading.savesHistory"
        static let usesCloudTranslation = "usesCloudTranslation"
        static let lineCount = "live.lineCount"
        static let sendsToTV = "tv.isEnabled"
        static let tvPosition = "tv.position"
        static let tvTextSize = "tv.textSize"
        static let tvShowsOriginal = "tv.showsOriginal"
        static let usesServer = "server.isEnabled"
        static let serverStyle = "server.style"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
    }

    func load() -> AppSettings {
        let fallback = AppSettings()
        var settings = AppSettings(
            source: defaults.string(forKey: Key.source).map(AppLanguage.init(code:)) ?? fallback.source,
            target: defaults.string(forKey: Key.target).map(AppLanguage.init(code:)) ?? fallback.target,
            languages: defaults.stringArray(forKey: Key.languages)?.map(AppLanguage.init(code:)) ?? fallback.languages
        )
        // Saved by an earlier version, which allowed it.
        if settings.pair.isSameLanguage {
            if settings.source == fallback.target {
                settings.source = fallback.source
            } else {
                settings.target = fallback.target
            }
        }
        if let value = defaults.object(forKey: Key.showsLiveActivity) as? Bool { settings.live.showsLiveActivity = value }
        if let value = defaults.object(forKey: Key.sendsNotifications) as? Bool { settings.live.sendsNotifications = value }
        if let value = defaults.object(forKey: Key.usesScreenCapture) as? Bool { settings.live.usesScreenCapture = value }
        if let value = defaults.object(forKey: Key.lineCount) as? Int { settings.live.lineCount = value }
        if let value = defaults.object(forKey: Key.isContinuous) as? Bool { settings.reading.isContinuous = value }
        if let value = defaults.object(forKey: Key.showsOriginal) as? Bool { settings.reading.showsOriginal = value }
        if let value = defaults.object(forKey: Key.savesHistory) as? Bool { settings.reading.savesHistory = value }
        if let value = defaults.string(forKey: Key.speed).flatMap(ReadingSettings.Speed.init) {
            settings.reading.speed = value
        }
        if let value = defaults.string(forKey: Key.textSize).flatMap(ReadingSettings.TextSize.init) {
            settings.reading.textSize = value
        }
        if let value = defaults.object(forKey: Key.usesCloudTranslation) as? Bool { settings.usesCloudTranslation = value }
        if let value = defaults.object(forKey: Key.sendsToTV) as? Bool { settings.tv.isEnabled = value }
        if let value = defaults.object(forKey: Key.tvShowsOriginal) as? Bool { settings.tv.showsOriginal = value }
        if let value = defaults.string(forKey: Key.tvPosition).flatMap(TVSettings.Position.init) {
            settings.tv.position = value
        }
        if let value = defaults.string(forKey: Key.tvTextSize).flatMap(ReadingSettings.TextSize.init) {
            settings.tv.textSize = value
        }
        if let value = defaults.object(forKey: Key.usesServer) as? Bool { settings.server.isEnabled = value }
        if let value = defaults.string(forKey: Key.serverStyle).flatMap(ServerSettings.Style.init) {
            settings.server.style = value
        }
        return settings
    }

    func save(_ settings: AppSettings) {
        defaults.set(settings.source.code, forKey: Key.source)
        defaults.set(settings.target.code, forKey: Key.target)
        defaults.set(settings.languages.map(\.code), forKey: Key.languages)
        defaults.set(settings.live.showsLiveActivity, forKey: Key.showsLiveActivity)
        defaults.set(settings.live.sendsNotifications, forKey: Key.sendsNotifications)
        defaults.set(settings.live.usesScreenCapture, forKey: Key.usesScreenCapture)
        defaults.set(settings.reading.isContinuous, forKey: Key.isContinuous)
        defaults.set(settings.reading.showsOriginal, forKey: Key.showsOriginal)
        defaults.set(settings.reading.savesHistory, forKey: Key.savesHistory)
        defaults.set(settings.reading.speed.rawValue, forKey: Key.speed)
        defaults.set(settings.reading.textSize.rawValue, forKey: Key.textSize)
        defaults.set(settings.usesCloudTranslation, forKey: Key.usesCloudTranslation)
        defaults.set(settings.live.lineCount, forKey: Key.lineCount)
        defaults.set(settings.tv.isEnabled, forKey: Key.sendsToTV)
        defaults.set(settings.tv.position.rawValue, forKey: Key.tvPosition)
        defaults.set(settings.tv.textSize.rawValue, forKey: Key.tvTextSize)
        defaults.set(settings.tv.showsOriginal, forKey: Key.tvShowsOriginal)
        defaults.set(settings.server.isEnabled, forKey: Key.usesServer)
        defaults.set(settings.server.style.rawValue, forKey: Key.serverStyle)
    }
}
