import Foundation

nonisolated enum AppError: Error, Equatable {
    case photoAccessDenied
    case photoAccessLimited
    case noScreenshot
    case unreadableImage
    case noText
    case sameLanguage
    case unsupportedLanguages
    case appGroupUnavailable
    case liveLanguageUnsupported
    case translationNeedsApp
    case notificationsDenied
    case captureFailed(String)
    case cloudKeyRejected
    case cloudLimitReached
    case cloudUnreachable
    case keyNotSaved
    case cameraUnavailable
    case cameraAccessDenied
    case cameraLanguageUnsupported
    case noLocalNetwork
    case tvServerFailed
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
        case .appGroupUnavailable: .errorAppGroupUnavailable
        case .liveLanguageUnsupported: .errorLiveLanguageUnsupported
        case .translationNeedsApp: .errorTranslationNeedsApp
        case .notificationsDenied: .errorNotificationsDenied
        case .captureFailed(let reason): .errorCaptureFailed(reason)
        case .cloudKeyRejected: .errorCloudKeyRejected
        case .cloudLimitReached: .errorCloudLimitReached
        case .cloudUnreachable: .errorCloudUnreachable
        case .keyNotSaved: .errorKeyNotSaved
        case .cameraUnavailable: .errorCameraUnavailable
        case .cameraAccessDenied: .errorCameraAccessDenied
        case .cameraLanguageUnsupported: .errorCameraLanguageUnsupported
        case .noLocalNetwork: .errorNoLocalNetwork
        case .tvServerFailed: .errorTvServerFailed
        case .translationFailed(let reason): .errorTranslationFailed(reason)
        }
    }

    /// Keeps known errors and wraps anything the system throws.
    init(_ error: any Error) {
        self = error as? AppError ?? .translationFailed(error.localizedDescription)
    }

    var isFixedInSystemSettings: Bool {
        [.photoAccessDenied, .photoAccessLimited, .notificationsDenied, .cameraAccessDenied].contains(self)
    }
}
