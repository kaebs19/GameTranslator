import Foundation

/// One saved translation. Text only, never an image.
nonisolated struct HistoryEntry: Codable, Identifiable, Equatable, Sendable {
    enum Source: String, Codable, CaseIterable, Sendable {
        case camera, photo, live
    }

    let id: UUID
    let original: String
    let translation: String
    let pair: LanguagePair
    let source: Source
    var date: Date
}
