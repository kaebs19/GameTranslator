import Foundation

/// The answer to "where do you play?" on the last introduction page, and where it leads.
enum PlaySetup: CaseIterable, Identifiable {
    /// A console or computer on a TV, with the translation over the game.
    case tvOverlay
    /// A console or computer on any screen, with the translation on the phone.
    case camera
    /// A game on this phone.
    case phoneGame

    var id: Self { self }

    var icon: String {
        switch self {
        case .tvOverlay: "tv"
        case .camera: "camera.viewfinder"
        case .phoneGame: "iphone"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .tvOverlay: .setupTvOverlay
        case .camera: .setupCamera
        case .phoneGame: .setupPhoneGame
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .tvOverlay: .setupTvOverlayDetail
        case .camera: .setupCameraDetail
        case .phoneGame: .setupPhoneGameDetail
        }
    }
}
