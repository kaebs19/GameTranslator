import Foundation

nonisolated enum TranslateFailure: Error, Equatable {
    case photoAccessDenied
    case photoAccessLimited
    case noScreenshot
    case unreadableImage
    case noText
    case sameLanguage
    case unsupportedLanguages
    case translationFailed(String)

    var message: LocalizedStringResource {
        switch self {
        case .photoAccessDenied: .errorPhotoAccessDenied
        case .photoAccessLimited: .errorPhotoAccessLimited
        case .noScreenshot: .errorNoScreenshot
        case .unreadableImage: .errorUnreadableImage
        case .noText: .errorNoText
        case .sameLanguage: .errorSameLanguage
        case .unsupportedLanguages: .errorUnsupportedLanguages
        case .translationFailed(let reason): .errorTranslationFailed(reason)
        }
    }

    var isFixedInSystemSettings: Bool { self == .photoAccessDenied || self == .photoAccessLimited }
}
