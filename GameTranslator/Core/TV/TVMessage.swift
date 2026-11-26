import Foundation

/// What a TV draws. The whole picture each time, so a TV that joins late needs nothing else.
nonisolated struct TVMessage: Encodable, Equatable, Sendable {
    struct Line: Encodable, Equatable, Sendable {
        let text: String
        /// Left out unless the user wants it.
        let original: String?
    }

    let lines: [Line]
    let isRTL: Bool
    let position: TVSettings.Position
    let size: String

    init(lines: [SharedTranslation.Line], target: AppLanguage, settings: TVSettings) {
        self.lines = lines.map {
            Line(text: $0.translation, original: settings.showsOriginal ? $0.original : nil)
        }
        isRTL = Locale.Language(identifier: target.code).characterDirection == .rightToLeft
        position = settings.position
        size = settings.textSize.rawValue
    }

    /// One server-sent event. JSON escapes line breaks, so it always fits one `data:` line.
    var event: Data { Self.event((try? JSONEncoder().encode(self)) ?? Data("{}".utf8)) }

    /// Tells a TV the phone is still there.
    static let ping = event(Data(#"{"ping":true}"#.utf8))

    private static func event(_ json: Data) -> Data { Data("data: ".utf8) + json + Data("\n\n".utf8) }
}
