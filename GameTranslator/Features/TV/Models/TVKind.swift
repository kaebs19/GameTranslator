import Foundation

/// How each kind of TV can show translations.
enum TVKind: CaseIterable, Identifiable {
    case android, samsung, lg, browser

    var id: Self { self }

    var icon: String {
        switch self {
        case .android, .samsung, .lg: "tv"
        case .browser: "safari"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .android: .tvKindAndroid
        case .samsung: .tvKindSamsung
        case .lg: .tvKindLg
        case .browser: .tvKindBrowser
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .android: .tvKindAndroidDetail
        case .samsung: .tvKindSamsungDetail
        case .lg: .tvKindLgDetail
        case .browser: .tvKindBrowserDetail
        }
    }
}
