import Darwin

/// This phone's address on the home network.
nonisolated protocol LocalAddressProviding: Sendable {
    func current() -> PhoneAddress?
}

nonisolated struct SystemLocalAddress: LocalAddressProviding {
    /// Wi-Fi, then wired adapters, then this phone's own hotspot. Never cellular.
    private static let interfaces = ["en0", "en1", "en2", "en3", "en4", "en5", "bridge100"]

    func current() -> PhoneAddress? {
        let found = addresses()
        return Self.interfaces.lazy.compactMap { found[$0] }.first
    }

    private func addresses() -> [String: PhoneAddress] {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0 else { return [:] }
        defer { freeifaddrs(list) }
        var result: [String: PhoneAddress] = [:]
        for entry in sequence(first: list, next: { $0?.pointee.ifa_next }) {
            guard let entry = entry?.pointee, let address = entry.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_INET), entry.ifa_flags & UInt32(IFF_UP) != 0 else { continue }
            let value = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
            }
            // 169.254.x.x means the network never gave an address.
            guard value >> 16 != 0xA9FE else { continue }
            result[String(cString: entry.ifa_name)] = PhoneAddress(value: value)
        }
        return result
    }
}
