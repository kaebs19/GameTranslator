import Foundation
import SwiftUI
import Testing
@testable import GameTranslator

@MainActor
struct InterfaceLanguageTests {
    private func withDefaults(_ body: (UserDefaults, String) throws -> Void) throws {
        let name = "interface-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults, name)
    }

    @Test func followsTheDeviceByDefault() throws {
        try withDefaults { defaults, _ in
            #expect(InterfaceLanguageModel(defaults: defaults).selection == .system)
        }
    }

    @Test func choiceIsRememberedAndHandedToTheSystem() throws {
        try withDefaults { defaults, name in
            let model = InterfaceLanguageModel(defaults: defaults)
            model.selection = .english
            #expect(InterfaceLanguageModel(defaults: defaults).selection == .english)
            // Read from the suite itself: a test run in a fixed language overrides this key.
            #expect(defaults.persistentDomain(forName: name)?["AppleLanguages"] as? [String] == ["en"])
            model.selection = .system
            #expect(InterfaceLanguageModel(defaults: defaults).selection == .system)
            #expect(defaults.persistentDomain(forName: name)?["AppleLanguages"] == nil)
        }
    }

    @Test func directionFollowsTheLanguage() {
        #expect(InterfaceLanguage.arabic.layoutDirection == .rightToLeft)
        #expect(InterfaceLanguage.english.layoutDirection == .leftToRight)
    }

    @Test func regionIsKept() {
        let device = Locale(identifier: "ar_SA")
        let english = InterfaceLanguage.english.locale(current: device)
        #expect(english.language.languageCode?.identifier == "en")
        #expect(english.region?.identifier == "SA")
    }

    @Test(arguments: [
        (["ar-SA", "en"], "ar"), (["en-GB", "ar"], "en"), (["fr-FR", "en-US"], "en"), (["ar-EG"], "ar")
    ])
    func deviceLanguageBecomesOneOfOurs(preferred: [String], expected: String) {
        #expect(InterfaceLanguage.supportedCode(forPreferences: preferred) == expected)
    }

    @Test func systemIsAlwaysOneOfOurs() {
        #expect(["ar", "en"].contains(InterfaceLanguage.system.code))
    }
}
