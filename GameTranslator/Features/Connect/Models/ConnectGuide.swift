import SwiftUI

/// One way to bring a game's text into the app. Every way ends in something that works today.
enum ConnectGuide: String, CaseIterable, Identifiable {
    case phone, stream, screen

    enum Action {
        case broadcast, camera
    }

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .phone: "iphone"
        case .stream: "gamecontroller.fill"
        case .screen: "tv.fill"
        }
    }

    var tint: Color {
        switch self {
        case .phone: .appAccent
        case .stream: .appSuccess
        case .screen: .appPink
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .phone: .connectPhone
        case .stream: .connectStream
        case .screen: .connectScreen
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .phone: .connectPhoneDetail
        case .stream: .connectStreamDetail
        case .screen: .connectScreenDetail
        }
    }

    var steps: [LocalizedStringResource] {
        switch self {
        case .phone: [.connectPhoneStep1, .connectPhoneStep2, .connectPhoneStep3]
        case .stream: [.connectStreamStep1, .connectStreamStep2, .connectStreamStep3]
        case .screen: [.connectScreenStep1, .connectScreenStep2, .connectScreenStep3]
        }
    }

    var action: Action {
        switch self {
        case .phone, .stream: .broadcast
        case .screen: .camera
        }
    }

    var actionTitle: LocalizedStringResource {
        switch action {
        case .broadcast: .connectOpenBroadcast
        case .camera: .connectOpenCamera
        }
    }

    var actionIcon: String {
        switch action {
        case .broadcast: "dot.radiowaves.left.and.right"
        case .camera: "camera.viewfinder"
        }
    }
}
