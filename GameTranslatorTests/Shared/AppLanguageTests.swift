import Foundation
import Testing
@testable import GameTranslator

struct AppLanguageTests {
    @Test(arguments: [
        ("en-US", "en"), ("en_GB", "en"), ("ar-SA", "ar"), ("ar-Arab-EG", "ar"), ("pt-BR", "pt"),
        ("zh-Hans", "zh-Hans"), ("zh", "zh-Hans"), ("zh-TW", "zh-Hant"), ("zh-Hant-HK", "zh-Hant"), ("nb", "nb")
    ])
    func collapsesRegionalVariants(input: String, expected: String) {
        #expect(AppLanguage(code: input).code == expected)
    }

    @Test func searchMatchesLocalAndNativeNames() {
        let arabicUI = Locale(identifier: "ar")
        let dutch = AppLanguage(code: "nl")
        #expect(dutch.matches("هولندية", in: arabicUI))
        #expect(dutch.matches("nederl", in: arabicUI))
        #expect(!dutch.matches("français", in: arabicUI))
    }

    @Test func settingsAlwaysListTheLanguagesInUse() {
        let settings = AppSettings(source: AppLanguage(code: "nl"), target: .arabic, languages: [.english, .english])
        #expect(settings.languages.map(\.code) == ["en", "nl", "ar"])
    }

    @Test func choosingTheOtherLanguageSwapsThem() {
        var settings = AppSettings()
        settings.source = .arabic
        #expect(settings.pair == LanguagePair(source: "ar", target: "en"))
        settings.target = .arabic
        #expect(settings.pair == LanguagePair(source: "en", target: "ar"))
        settings.target = .arabic
        #expect(settings.pair == LanguagePair(source: "en", target: "ar"))
    }

    @Test(arguments: [("ar", "en", "ar"), ("en", "en", "ar"), ("fr", "fr", "ar")])
    func savedSameLanguageIsRepaired(saved: String, source: String, target: String) throws {
        let name = "settings-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(saved, forKey: "sourceLanguage")
        defaults.set(saved, forKey: "targetLanguage")
        let pair = UserDefaultsSettingsStore(defaults: defaults).load().pair
        #expect(pair == LanguagePair(source: source, target: target))
    }

    @Test func languagesInUseCannotBeRemoved() {
        var settings = AppSettings()
        settings.remove(.english)
        settings.remove(.arabic)
        settings.remove(AppLanguage(code: "fr"))
        #expect(settings.languages.contains(.english) && settings.languages.contains(.arabic))
        #expect(!settings.languages.contains(AppLanguage(code: "fr")))
    }
}
