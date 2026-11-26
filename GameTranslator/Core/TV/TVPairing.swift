import Foundation

nonisolated struct PairedTV: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let token: String
}

/// Decides which TVs may connect. A PIN works only while the user looks at it.
nonisolated struct TVPairing: Sendable {
    enum Outcome: Equatable, Sendable {
        case paired(PairedTV)
        case rejected
        /// Too many wrong PINs: the PIN changed and new tries wait.
        case locked
    }

    static let maximumFailures = 5
    static let lockDuration: TimeInterval = 30
    static let maximumTVs = 8
    private static let maximumNameLength = 40

    private(set) var tvs: [PairedTV]
    /// `nil` while pairing is closed.
    private(set) var pin: String?
    private var failures = 0
    private var lockedUntil = Date.distantPast
    private let makePIN: @Sendable () -> String

    init(tvs: [PairedTV] = [], makePIN: @escaping @Sendable () -> String = PairingCode.randomPIN) {
        self.tvs = tvs
        self.makePIN = makePIN
    }

    mutating func open() { pin = makePIN() }

    mutating func close() { pin = nil }

    /// Reopening the screen does not clear failures, or it would also clear the limit.
    mutating func pair(pin attempt: String, name: String, now: Date = .now) -> Outcome {
        guard now >= lockedUntil else { return .locked }
        guard let pin else { return .rejected }
        guard attempt == pin else {
            failures += 1
            guard failures >= Self.maximumFailures else { return .rejected }
            failures = 0
            lockedUntil = now.addingTimeInterval(Self.lockDuration)
            self.pin = makePIN()
            return .locked
        }
        failures = 0
        // A PIN pairs one TV.
        self.pin = makePIN()
        let cleaned = name.components(separatedBy: .controlCharacters).joined()
            .trimmingCharacters(in: .whitespaces).prefix(Self.maximumNameLength)
        let tv = PairedTV(id: UUID(), name: cleaned.isEmpty ? "TV" : String(cleaned), token: Self.makeToken())
        tvs = (tvs + [tv]).suffix(Self.maximumTVs)
        return .paired(tv)
    }

    func tv(token: String) -> PairedTV? { tvs.first { $0.token == token } }

    mutating func remove(_ id: PairedTV.ID) { tvs.removeAll { $0.id == id } }

    /// `SystemRandomNumberGenerator` is cryptographically secure.
    private static func makeToken() -> String {
        (0..<32).map { _ in String(format: "%02x", UInt8.random(in: .min ... .max)) }.joined()
    }
}
