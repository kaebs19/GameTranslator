import Foundation
import Observation

/// Hands work from App Intents to the visible screen.
@Observable
final class AppRouter {
    static let shared = AppRouter()

    enum Request: Equatable {
        case latestScreenshot
        case image(Data)
    }

    private(set) var request: Request?

    func open(_ request: Request) {
        self.request = request
    }

    func takeRequest() -> Request? {
        defer { request = nil }
        return request
    }
}
