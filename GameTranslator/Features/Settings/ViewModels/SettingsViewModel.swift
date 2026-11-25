import Foundation
import Observation

@Observable
final class SettingsViewModel {
    var settings: AppSettings {
        didSet { store.save(settings) }
    }
    var error: AppError?
    let supportsScreenCapture: Bool
    private(set) var isCacheCleared = false
    /// `nil` until the system list has loaded.
    private(set) var catalogLanguages: [AppLanguage]?

    private let store: any SettingsStoring
    private let catalog: any LanguageCatalogProviding
    private let readableLanguages: Set<AppLanguage>
    private let notifications: any NotificationProviding
    private let clearCacheAction: () async -> Void

    init(
        store: any SettingsStoring,
        catalog: any LanguageCatalogProviding,
        readableLanguages: Set<AppLanguage>,
        notifications: any NotificationProviding,
        supportsScreenCapture: Bool,
        clearCache: @escaping () async -> Void
    ) {
        self.store = store
        self.catalog = catalog
        self.readableLanguages = readableLanguages
        self.notifications = notifications
        self.supportsScreenCapture = supportsScreenCapture
        settings = store.load()
        clearCacheAction = clearCache
    }

    /// Another screen changed the stored settings.
    func reload() {
        let stored = store.load()
        if stored != settings { settings = stored }
    }

    // MARK: Languages

    var targetChoices: [AppLanguage] { settings.languages }

    /// Only languages whose text can be recognized, plus the current choice.
    var sourceChoices: [AppLanguage] {
        settings.languages.filter { canRead($0) || $0 == settings.source }
    }

    func canRead(_ language: AppLanguage) -> Bool { readableLanguages.contains(language) }

    func loadCatalog() async {
        guard catalogLanguages == nil else { return }
        catalogLanguages = await catalog.translatableLanguages()
    }

    func addedLanguages(matching query: String, locale: Locale) -> [AppLanguage] {
        filter(settings.languages, query, locale)
    }

    func availableLanguages(matching query: String, locale: Locale) -> [AppLanguage] {
        let remaining = (catalogLanguages ?? []).filter { !settings.languages.contains($0) }
        return filter(remaining, query, locale).sorted {
            $0.displayName(in: locale).localizedStandardCompare($1.displayName(in: locale)) == .orderedAscending
        }
    }

    func add(_ language: AppLanguage) { settings.add(language) }

    func remove(_ language: AppLanguage) { settings.remove(language) }

    private func filter(_ languages: [AppLanguage], _ query: String, _ locale: Locale) -> [AppLanguage] {
        let query = TextNormalizer.collapsingWhitespace(query)
        return query.isEmpty ? languages : languages.filter { $0.matches(query, in: locale) }
    }

    // MARK: Live

    /// Turned on only once iOS allows it, so the switch never promises what cannot happen.
    func setNotifications(_ isOn: Bool) async {
        settings.live.sendsNotifications = isOn
        guard isOn, await !notifications.requestPermission() else { return }
        settings.live.sendsNotifications = false
        error = .notificationsDenied
    }

    // MARK: Cache

    func clearCache() async {
        await clearCacheAction()
        isCacheCleared = true
    }
}
