import Foundation

/// Digits typed on the TV: where this phone is, then a PIN.
/// A TV remote only types digits easily, and there is no server of ours to look a short code up.
/// The same decoding lives in `TVReceiver.html` and in the Android TV app.
nonisolated struct PairingCode: Equatable, Sendable {
    static let pinLength = 4

    let address: PhoneAddress
    let pin: String

    /// First digit: which private range, and so how many digits follow.
    private enum Range: Int, CaseIterable {
        case home = 1, hotspot, large, any

        var base: UInt32 {
            switch self {
            case .home: 0xC0A8_0000
            case .hotspot: 0xAC10_0000
            case .large: 0x0A00_0000
            case .any: 0
            }
        }
        var hostBits: UInt32 {
            switch self {
            case .home: 16
            case .hotspot: 20
            case .large: 24
            case .any: 32
            }
        }
        var digits: Int {
            switch self {
            case .home: 5
            case .hotspot: 7
            case .large: 8
            case .any: 10
            }
        }
        var mask: UInt32 { self == .any ? 0 : ~((1 << hostBits) - 1) }
    }

    /// The part that says where the phone is.
    var addressDigits: String {
        let range = Range.allCases.first { address.value & $0.mask == $0.base } ?? .any
        let host = String(address.value & ~range.mask)
        let padding = String(repeating: "0", count: range.digits - host.count)
        return "\(range.rawValue)\(padding)\(host)"
    }

    var digits: String { addressDigits + pin }

    init(address: PhoneAddress, pin: String) {
        self.address = address
        self.pin = pin
    }

    init?(digits: String) {
        guard let first = digits.first?.wholeNumberValue, let range = Range(rawValue: first),
              digits.count == 1 + range.digits + Self.pinLength,
              let host = UInt32(digits.dropFirst().prefix(range.digits)), host & range.mask == 0
        else { return nil }
        self.init(address: PhoneAddress(value: range.base | host), pin: String(digits.suffix(Self.pinLength)))
    }

    static func randomPIN() -> String {
        (0..<pinLength).map { _ in String(Int.random(in: 0...9)) }.joined()
    }
}

nonisolated struct PhoneAddress: Equatable, Sendable, CustomStringConvertible {
    let value: UInt32

    init(value: UInt32) { self.value = value }

    init?(_ text: String) {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false).map { UInt8($0) }
        guard parts.count == 4 else { return nil }
        var value: UInt32 = 0
        for part in parts {
            guard let part else { return nil }
            value = value << 8 | UInt32(part)
        }
        self.value = value
    }

    var description: String {
        [24, 16, 8, 0].map { String(value >> UInt32($0) & 0xFF) }.joined(separator: ".")
    }
}
