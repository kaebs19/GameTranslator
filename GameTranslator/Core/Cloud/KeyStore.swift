import Foundation
import Security

nonisolated protocol KeyStoring: Sendable {
    func load() -> String?
    func save(_ key: String) throws
    func remove()
}

/// Keeps the API key in the Keychain of this device only; it is not backed up or synced.
nonisolated struct KeychainKeyStore: KeyStoring {
    private let account: String

    init(account: String = "cloudTranslationKey") {
        self.account = account
    }

    func load() -> String? {
        var query = baseQuery
        query[kSecReturnData] = true
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func save(_ key: String) throws {
        remove()
        var query = baseQuery
        query[kSecValueData] = Data(key.utf8)
        // Readable after the first unlock, for translating in the background.
        query[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else { throw AppError.keyNotSaved }
    }

    func remove() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: "CloudTranslation", kSecAttrAccount: account]
    }
}
