import Foundation
import Testing
@testable import GameTranslator

@MainActor
struct SettingsViewModelTests {
    private let store = InMemorySettingsStore()
    private let notifications = StubNotifications()
    private let english = Locale(identifier: "en")
    private let dutch = AppLanguage(code: "nl")
    private let hebrew = AppLanguage(code: "he")

    private func makeViewModel(
        catalog: [AppLanguage] = [], clearCache: @escaping () async -> Void = {}
    ) -> SettingsViewModel {
        SettingsViewModel(
            store: store, catalog: StubCatalog(languages: catalog),
            readableLanguages: [.english, dutch], notifications: notifications,
            supportsScreenCapture: true, clearCache: clearCache
        )
    }

    @Test func changesAreSavedImmediately() {
        let viewModel = makeViewModel()
        viewModel.settings.source = AppLanguage(code: "ja")
        viewModel.settings.target = AppLanguage(code: "tr")
        #expect(store.load().pair == LanguagePair(source: "ja", target: "tr"))
    }

    @Test func addedLanguageIsSavedAndOffered() async {
        let viewModel = makeViewModel(catalog: [.english, dutch, hebrew])
        await viewModel.loadCatalog()
        #expect(viewModel.availableLanguages(matching: "", locale: english) == [dutch, hebrew])
        viewModel.add(dutch)
        #expect(store.load().languages.contains(dutch))
        #expect(viewModel.sourceChoices.contains(dutch) && viewModel.targetChoices.contains(dutch))
        #expect(viewModel.availableLanguages(matching: "", locale: english) == [hebrew])
    }

    @Test func unreadableLanguageIsOnlyOfferedAsTarget() {
        let viewModel = makeViewModel()
        viewModel.add(hebrew)
        #expect(viewModel.targetChoices.contains(hebrew))
        #expect(!viewModel.sourceChoices.contains(hebrew))
    }

    @Test func currentSourceIsAlwaysOffered() {
        let viewModel = makeViewModel()
        viewModel.settings.source = hebrew
        #expect(viewModel.sourceChoices.contains(hebrew))
    }

    @Test func removedLanguageBecomesAvailableAgain() async {
        let viewModel = makeViewModel(catalog: [dutch])
        await viewModel.loadCatalog()
        viewModel.add(dutch)
        viewModel.remove(dutch)
        #expect(!store.load().languages.contains(dutch))
        #expect(viewModel.availableLanguages(matching: "", locale: english) == [dutch])
    }

    @Test func searchFiltersBothLists() async {
        let viewModel = makeViewModel(catalog: [dutch, hebrew])
        await viewModel.loadCatalog()
        #expect(viewModel.availableLanguages(matching: " dut ", locale: english) == [dutch])
        #expect(viewModel.addedLanguages(matching: "arabic", locale: english) == [.arabic])
    }

    @Test func clearingTheCacheIsReported() async {
        var calls = 0
        let viewModel = makeViewModel(clearCache: { calls += 1 })
        await viewModel.clearCache()
        #expect(calls == 1)
        #expect(viewModel.isCacheCleared)
    }

    @Test func storePersistsAndFallsBackToEnglishAndArabic() throws {
        let name = "settings-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = UserDefaultsSettingsStore(defaults: defaults)
        #expect(store.load() == AppSettings())
        var custom = AppSettings(source: dutch, target: hebrew, languages: [dutch, hebrew])
        custom.live.showsLiveActivity = false
        custom.live.sendsNotifications = true
        custom.live.lineCount = 4
        custom.live.usesScreenCapture = true
        custom.reading = ReadingSettings(
            speed: .fast, isContinuous: false, showsOriginal: false, textSize: .large, savesHistory: false
        )
        custom.usesCloudTranslation = true
        store.save(custom)
        #expect(UserDefaultsSettingsStore(defaults: defaults).load() == custom)
    }

    @Test func settingsSavedBeforeTheListExistedStillLoad() throws {
        let name = "settings-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("zh-Hans", forKey: "sourceLanguage")
        defaults.set("tr", forKey: "targetLanguage")
        let loaded = UserDefaultsSettingsStore(defaults: defaults).load()
        #expect(loaded.pair == LanguagePair(source: "zh-Hans", target: "tr"))
        #expect(loaded.languages == AppLanguage.defaults)
    }

    @Test func notificationsNeedPermission() async {
        let viewModel = makeViewModel()
        await viewModel.setNotifications(true)
        #expect(store.load().live.sendsNotifications)
        #expect(viewModel.error == nil)
        await viewModel.setNotifications(false)
        notifications.isAllowed = false
        await viewModel.setNotifications(true)
        #expect(!store.load().live.sendsNotifications)
        #expect(viewModel.error == .notificationsDenied)
    }

    @Test func lineCountStaysInRange() {
        var live = LiveSettings()
        live.lineCount = 99
        #expect(live.lineCount == 4)
        live.lineCount = 0
        #expect(live.lineCount == 1)
    }
}
