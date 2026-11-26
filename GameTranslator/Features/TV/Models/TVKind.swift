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

    var steps: [LocalizedStringResource] {
        switch self {
        case .android: [.tvKindAndroidStep1, .tvKindAndroidStep2, .tvKindAndroidStep3]
        case .samsung, .lg: [.tvKindSamsungStep1, .tvKindSamsungStep2, .tvKindSamsungStep3]
        case .browser: [.tvKindBrowserStep1, .tvKindBrowserStep2, .tvKindBrowserStep3]
        }
    }

    /// Only the browser needs the address; the other apps find it in the code.
    var needsAddress: Bool { self == .browser }
    var note: LocalizedStringResource? { self == .browser ? nil : .tvKindInputNote }
}
