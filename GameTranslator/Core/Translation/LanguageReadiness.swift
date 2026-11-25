import Translation

nonisolated enum LanguageReadiness: Equatable, Sendable {
    case unknown, ready, downloadable, unsupported

    init(_ status: LanguageAvailability.Status) {
        switch status {
        case .installed: self = .ready
        case .supported: self = .downloadable
        case .unsupported: self = .unsupported
        @unknown default: self = .unknown
        }
    }
}

protocol LanguagePreparing: AnyObject {
    func readiness(of pair: LanguagePair) async -> LanguageReadiness
    /// Lets the system offer the download. Returns when it is finished or declined.
    func prepare(_ pair: LanguagePair) async throws
}
