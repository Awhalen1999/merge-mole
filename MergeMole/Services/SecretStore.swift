import Foundation

/// Where secrets live. Per PLAN.md, the GitHub token and any BYO API keys go in
/// the Keychain — never UserDefaults. A `KeychainSecretStore` conforming to this
/// arrives with real auth at Step 3; everything else only ever sees the protocol.
protocol SecretStore: AnyObject {
    func string(for key: SecretKey) -> String?
    func set(_ value: String?, for key: SecretKey)
}

/// Known secret slots, kept in one place so call sites can't typo a raw string.
enum SecretKey: String, CaseIterable, Sendable {
    case githubToken
    case remoteModelAPIKey
}

/// In-memory stand-in so the seam compiles and runs today. Values do NOT persist
/// across launches — that's deliberate; the real Keychain implementation is what
/// makes them durable. Never extend this to write to disk/UserDefaults.
final class InMemorySecretStore: SecretStore {
    private var storage: [SecretKey: String] = [:]

    func string(for key: SecretKey) -> String? { storage[key] }

    func set(_ value: String?, for key: SecretKey) {
        if let value { storage[key] = value } else { storage[key] = nil }
    }
}
