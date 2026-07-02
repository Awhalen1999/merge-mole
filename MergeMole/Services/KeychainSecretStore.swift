import Foundation
import Security

/// Keychain-backed `SecretStore` — the durable home for the GitHub token and any
/// BYO API key. Items are generic passwords keyed by `SecretKey`, scoped to one
/// service string.
///
/// Writes are delete-then-add: one path, no add-vs-update branching to get wrong.
final class KeychainSecretStore: SecretStore {
    private let service: String

    init(service: String = "app.mergemole.MergeMole") {
        self.service = service
    }

    func string(for key: SecretKey) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }
        return value
    }

    @discardableResult
    func set(_ value: String?, for key: SecretKey) -> Bool {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
        SecItemDelete(base as CFDictionary)   // a "not found" here is fine — we ignore it

        // Clearing a slot: the delete above is the whole operation, and succeeded.
        guard let value, let data = value.data(using: .utf8) else { return true }

        var insert = base
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        // Report whether the write actually landed, so the caller can tell the user
        // instead of claiming success on a locked/policy-blocked Keychain.
        return SecItemAdd(insert as CFDictionary, nil) == errSecSuccess
    }
}
