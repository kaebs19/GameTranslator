import Foundation
import Observation
import SwiftUI

/// Language of the app's own screens, separate from what it translates.
nonisolated enum InterfaceLanguage: String, CaseIterable, Sendable {
    case system, arabic, english

    /// Code of one of the app's own languages.
    var code: String {
        switch self {
        case .system: Self.deviceCode
        case .arabic: "ar"
        case .english: "en"
        }
    }

    /// Asks the device rather than `Locale.current`, which keeps the language the app was launched in.
    private static var deviceCode: String {
        let preferred = CFPreferencesCopyValue(
            "AppleLanguages" as CFString, kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser, kCFPreferencesAnyHost
        ) as? [String]
        return supportedCode(forPreferences: preferred ?? Locale.preferredLanguages)
    }

    static func supportedCode(forPreferences preferred: [String]) -> String {
        Bundle.preferredLocalizations(from: ["ar", "en"], forPreferences: preferred).first ?? "ar"
    }

    /// Keeps the user's region, so dates and numbers stay familiar.
    func locale(current: Locale = .current) -> Locale {
        var components = Locale.Components(locale: current)
        components.languageComponents = Locale.Language.Components(
            languageCode: Locale.LanguageCode(code), script: nil, region: components.languageComponents.region
        )
        return Locale(components: components)
    }

    var layoutDirection: LayoutDirection {
        Locale.Language(identifier: code).characterDirection == .rightToLeft ? .rightToLeft : .leftToRight
    }
}

/// Remembers the choice. SwiftUI follows it at once; permission prompts and other
/// system-drawn text follow from the next launch, through `AppleLanguages`.
@Observable
final class InterfaceLanguageModel {
    private enum Key {
        static let choice = "interfaceLanguage"
        static let system = "AppleLanguages"
    }

    var selection: InterfaceLanguage {
        didSet {
            guard selection != oldValue else { return }
            defaults.set(selection.rawValue, forKey: Key.choice)
            if selection == .system {
                defaults.removeObject(forKey: Key.system)
            } else {
                defaults.set([selection.code], forKey: Key.system)
            }
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selection = defaults.string(forKey: Key.choice).flatMap(InterfaceLanguage.init) ?? .system
    }
}

extension View {
    /// Needed on the root and again inside every sheet: one already on screen
    /// does not inherit a later change.
    func interfaceLanguage(_ language: InterfaceLanguage) -> some View {
        environment(\.locale, language.locale())
            .environment(\.layoutDirection, language.layoutDirection)
    }
}
