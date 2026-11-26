import Foundation

/// TVs linked through the SubGG server. View models use this, not the client.
protocol ServerTVLinking: Sendable {
    func newTVCode() async throws -> String
    func tvs() async throws -> [ServerTV]
    func removeTV(_ id: String) async throws
}

extension SubGGClient: ServerTVLinking {}
