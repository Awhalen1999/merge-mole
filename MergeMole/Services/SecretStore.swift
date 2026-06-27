import Foundation

/// Where secrets live. Per docs/plan.md, the GitHub token and any BYO API keys go in
/// the Keychain — never UserDefaults. Everything else only ever sees this protocol;
/// `KeychainSecretStore` is the real impl, `InMemorySecretStore` backs previews/tests.
protocol SecretStore: AnyObject {
    func string(for key: SecretKey) -> String?
    func set(_ value: String?, for key: SecretKey)
}

/// Known secret slots, kept in one place so call sites can't typo a raw string.
/// These are the *only* secrets the app stores; both live in the macOS Keychain
/// (`KeychainSecretStore`, service `app.mergemole.MergeMole`). `CaseIterable` lets a
/// factory reset clear every slot without naming them.
enum SecretKey: String, CaseIterable, Sendable {
    case githubToken          // GitHub personal access token
    case remoteModelAPIKey    // Custom-model (BYO) API key
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
