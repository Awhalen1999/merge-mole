import Foundation
import Observation

/// How the user wants AI to run (chosen in Settings → AI). All three funnel
/// through one `VerdictState` the card branches on, so they stay seamless.
enum AIMode: String, CaseIterable, Identifiable, Sendable {
    case onDevice       // Foundation Models (default)
    case bringYourOwn   // user-supplied key + endpoint (hosted or Ollama)
    case off            // no model; cards collapse to data-only

    var id: String { rawValue }

    var label: String {
        switch self {
        case .onDevice:     return "On-device"
        case .bringYourOwn: return "Bring your own"
        case .off:          return "Off"
        }
    }

    /// One-line explanation for the Settings / onboarding UI.
    var detail: String {
        switch self {
        case .onDevice:     return "Apple's on-device model. Free, private, no key. Needs Apple Silicon."
        case .bringYourOwn: return "Use your own API key + endpoint — a hosted model or local Ollama. (Coming soon.)"
        case .off:          return "No AI. Cards show data only — title, repo, size, CI. Still a fast list."
        }
    }
}

/// The top-level filters in the panel's tab bar.
enum PRTab: String, CaseIterable, Identifiable, Sendable {
    case needsReview    // waiting on *you*
    case mine           // authored by you
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .needsReview: return "Needs Review"
        case .mine:        return "Mine"
        case .all:         return "All"
        }
    }
}

/// Outcome of a connect attempt, for inline UI feedback.
enum GitHubConnection: Sendable {
    case connected(login: String)
    case failed(message: String)
}

/// The single source of truth, shared across the menu-bar panel and the Settings
/// window via `.environment`. Owns the PR list + verdicts, the selected tab, and
/// the user's persisted preferences. Depends only on the service *protocols*, so
/// swapping fakes for real backends (Steps 4, 6) is a one-line change.
@MainActor
@Observable
final class AppModel {

    // MARK: Dependencies (the seams)

    private let prProvider: PRProvider
    /// An explicitly injected engine (previews/tests). In production this is nil
    /// and `activeEngine` resolves the real engine from `aiMode`.
    private let injectedEngine: VerdictEngine?
    let secrets: SecretStore

    private let verdictCache = VerdictCache()
    private static let maxConcurrentVerdicts = 4

    private(set) var currentUser: String

    // MARK: PR state

    private(set) var pullRequests: [PullRequest] = []
    private(set) var verdicts: [PullRequest.ID: VerdictState] = [:]
    private(set) var isLoading = false
    private(set) var loadError: String?

    var selectedTab: PRTab = .needsReview

    // MARK: Persisted preferences

    var aiMode: AIMode {
        didSet {
            guard aiMode != oldValue else { return }
            UserDefaults.standard.set(aiMode.rawValue, forKey: Key.aiMode)
            Task { await recomputeVerdicts() }
        }
    }

    /// BYO endpoint URL is not a secret, so it lives in UserDefaults. The BYO API
    /// key and the GitHub token go through `secrets` (Keychain).
    var byoEndpoint: String {
        didSet { UserDefaults.standard.set(byoEndpoint, forKey: Key.byoEndpoint) }
    }

    private(set) var hasCompletedOnboarding: Bool
    private(set) var isGitHubConnected: Bool

    /// Public so the App scene's `defaultLaunchBehavior` reads the exact same key.
    static let onboardedDefaultsKey = "hasCompletedOnboarding"

    private enum Key {
        static let aiMode = "aiMode"
        static let byoEndpoint = "byoEndpoint"
    }

    // MARK: Init

    init(
        prProvider: PRProvider? = nil,
        verdictEngine: VerdictEngine? = nil,
        secrets: SecretStore? = nil,
        currentUser: String? = nil,
        onboarded: Bool? = nil      // overridable for previews/tests
    ) {
        let secrets = secrets ?? KeychainSecretStore()
        self.prProvider = prProvider ?? GitHubPRProvider(secrets: secrets)
        self.injectedEngine = verdictEngine
        self.secrets = secrets
        self.currentUser = currentUser ?? SampleData.currentUser

        let defaults = UserDefaults.standard
        self.aiMode = AIMode(rawValue: defaults.string(forKey: Key.aiMode) ?? "") ?? .onDevice
        self.byoEndpoint = defaults.string(forKey: Key.byoEndpoint) ?? ""
        self.hasCompletedOnboarding = onboarded ?? defaults.bool(forKey: Self.onboardedDefaultsKey)
        self.isGitHubConnected = secrets.string(for: .githubToken) != nil
    }

    // MARK: GitHub connection

    /// Sanitize → verify with GitHub → store only if valid → load. A token is
    /// never saved without GitHub confirming it, so the "garbage token" failure
    /// mode can't happen. Returns the outcome for inline UI feedback.
    func connect(rawToken: String) async -> GitHubConnection {
        let token = GitHubToken.sanitize(rawToken)
        guard !token.isEmpty else { return .failed(message: "Enter a token.") }
        do {
            let login = try await GitHubAPI.viewerLogin(token: token)
            secrets.set(token, for: .githubToken)
            isGitHubConnected = true
            currentUser = login
            await load()
            return .connected(login: login)
        } catch {
            return .failed(message: error.localizedDescription)
        }
    }

    func disconnectGitHub() {
        secrets.set(nil, for: .githubToken)
        isGitHubConnected = false
        pullRequests = []
        verdicts = [:]
        loadError = nil
    }

    // MARK: BYO API key (non-displayed; lives in Keychain)

    var byoAPIKey: String { secrets.string(for: .remoteModelAPIKey) ?? "" }

    func setBYOAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        secrets.set(trimmed.isEmpty ? nil : trimmed, for: .remoteModelAPIKey)
    }

    // MARK: Onboarding

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: Self.onboardedDefaultsKey)
    }

    /// Replay first-run setup. Pair with opening the onboarding window.
    func resetOnboarding() {
        hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: Self.onboardedDefaultsKey)
    }

    // MARK: Derived views of state

    var visiblePullRequests: [PullRequest] {
        pullRequests(for: selectedTab).sorted { lhs, rhs in
            let lp = priority(of: lhs), rp = priority(of: rhs)
            if lp != rp { return lp > rp }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    func pullRequests(for tab: PRTab) -> [PullRequest] {
        switch tab {
        case .all:
            return pullRequests
        case .mine:
            return pullRequests.filter { $0.author == currentUser }
        case .needsReview:
            return pullRequests.filter {
                $0.author != currentUser && $0.reviewState == .pending && !$0.isDraft
            }
        }
    }

    var tabCounts: [PRTab: Int] {
        Dictionary(uniqueKeysWithValues: PRTab.allCases.map { ($0, pullRequests(for: $0).count) })
    }

    func verdictState(for pr: PullRequest) -> VerdictState {
        verdicts[pr.id] ?? (activeEngine == nil ? .off : .loading)
    }

    /// The engine for the current mode, or nil when verdicts should be `.off`
    /// (mode off, on-device unavailable, or BYO not yet wired). An injected
    /// engine (previews/tests) overrides the on-device / BYO resolution.
    private var activeEngine: VerdictEngine? {
        switch aiMode {
        case .off:
            return nil
        case .onDevice:
            if let injectedEngine { return injectedEngine }
            return FoundationModelsEngine.isAvailable ? FoundationModelsEngine() : nil
        case .bringYourOwn:
            if let injectedEngine { return injectedEngine }
            return nil   // real RemoteVerdictEngine is the next step
        }
    }

    /// On-device AI was chosen but this Mac can't run it (Intel, or Apple
    /// Intelligence off). Surfaced in Settings; cards fall back to data-only.
    var onDeviceUnavailable: Bool {
        aiMode == .onDevice && injectedEngine == nil && !FoundationModelsEngine.isAvailable
    }

    // MARK: Loading

    func load() async {
        guard isGitHubConnected else { return }   // RootView shows the connect state
        isLoading = true
        loadError = nil
        do {
            let result = try await prProvider.fetchPullRequests()
            if let viewer = result.viewer { currentUser = viewer }
            pullRequests = result.pullRequests
            isLoading = false
            await recomputeVerdicts()
        } catch {
            loadError = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: Verdicts

    private func recomputeVerdicts() async {
        guard let engine = activeEngine else {
            for pr in pullRequests { verdicts[pr.id] = .off }
            return
        }

        // Serve unchanged PRs straight from cache; only run the model on the
        // ones whose content signature changed (or are new).
        var stale: [PullRequest] = []
        for pr in pullRequests {
            if let cached = verdictCache.verdict(for: pr) {
                verdicts[pr.id] = .ready(cached)
            } else {
                verdicts[pr.id] = .loading
                stale.append(pr)
            }
        }
        guard !stale.isEmpty else { return }

        // Bounded concurrency: the on-device model shouldn't be hit with dozens
        // of requests at once. Cards fill in as each verdict lands.
        await withTaskGroup(of: (PullRequest, VerdictState).self) { group in
            var next = 0
            func schedule() {
                guard next < stale.count else { return }
                let pr = stale[next]
                next += 1
                group.addTask {
                    do { return (pr, .ready(try await engine.verdict(for: pr))) }
                    catch { return (pr, .failed("Couldn't analyze this PR.")) }
                }
            }
            for _ in 0..<min(Self.maxConcurrentVerdicts, stale.count) { schedule() }
            for await (pr, state) in group {
                verdicts[pr.id] = state
                if case .ready(let verdict) = state { verdictCache.store(verdict, for: pr) }
                schedule()
            }
        }
        verdictCache.persist()
    }

    private func priority(of pr: PullRequest) -> Priority {
        if case .ready(let verdict) = verdictState(for: pr) { return verdict.priority }
        return .normal
    }
}
