import Foundation

/// Where secrets live: the GitHub token and any BYO API keys go in the Keychain,
/// never UserDefaults. Everything else only sees this protocol; `KeychainSecretStore`
/// is the real implementation, `InMemorySecretStore` backs previews and tests.
protocol SecretStore: AnyObject {
    func string(for key: SecretKey) -> String?
    /// Returns whether the write succeeded. Callers that must confirm a secret is
    /// durably saved (e.g. the GitHub connect flow) check this; others can ignore it.
    @discardableResult func set(_ value: String?, for key: SecretKey) -> Bool
}

/// Known secret slots, kept in one place so call sites can't typo a raw string.
/// These are the *only* secrets the app stores; both live in the macOS Keychain
/// (`KeychainSecretStore`, service `app.mergemole.MergeMole`). `CaseIterable` lets a
/// factory reset clear every slot without naming them.
enum SecretKey: String, CaseIterable, Sendable {
    case githubToken          // GitHub personal access token
    case remoteModelAPIKey    // Custom-model (BYO) API key
}

/// In-memory stand-in for previews and tests. Values do not persist across launches
/// by design — durability is the Keychain implementation's job, so this must never
/// write to disk or UserDefaults.
final class InMemorySecretStore: SecretStore {
    private var storage: [SecretKey: String] = [:]

    func string(for key: SecretKey) -> String? { storage[key] }

    @discardableResult
    func set(_ value: String?, for key: SecretKey) -> Bool {
        if let value { storage[key] = value } else { storage[key] = nil }
        return true
    }
}
