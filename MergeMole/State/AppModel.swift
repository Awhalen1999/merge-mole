import Foundation
import Observation

/// How the user wants AI to run (chosen in advanced settings, per PLAN.md).
/// All three must feel seamless — that seamlessness is enforced by funnelling
/// every mode through one `VerdictState` the card branches on.
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

/// The single source of truth the UI observes. Owns the PR list, each PR's
/// verdict state, the selected tab, and the AI mode. It depends only on the
/// service *protocols*, so swapping fakes for real implementations (Steps 3, 5)
/// is a one-line change in `init` — the views never notice.
@MainActor
@Observable
final class AppModel {

    // MARK: Dependencies (the seams)

    private let prProvider: PRProvider
    private let verdictEngine: VerdictEngine
    let secrets: SecretStore

    /// Resolved from `provider` later; the signed-in GitHub user. Fixed for now.
    private(set) var currentUser: String

    // MARK: Observable state

    private(set) var pullRequests: [PullRequest] = []
    private(set) var verdicts: [PullRequest.ID: VerdictState] = [:]
    private(set) var isLoading = false
    private(set) var loadError: String?

    var selectedTab: PRTab = .needsReview

    var aiMode: AIMode {
        didSet {
            guard aiMode != oldValue else { return }
            Task { await recomputeVerdicts() }
        }
    }

    // MARK: Init

    /// Dependencies default to the sample wiring. They're resolved here in the
    /// init body (which is main-actor-isolated) rather than as default argument
    /// values (whose generators are nonisolated) — injecting any one for tests
    /// or the real backends still works.
    init(
        prProvider: PRProvider? = nil,
        verdictEngine: VerdictEngine? = nil,
        secrets: SecretStore? = nil,
        aiMode: AIMode = .onDevice,
        currentUser: String? = nil
    ) {
        self.prProvider = prProvider ?? SamplePRProvider()
        self.verdictEngine = verdictEngine ?? SampleVerdictEngine()
        self.secrets = secrets ?? InMemorySecretStore()
        self.aiMode = aiMode
        self.currentUser = currentUser ?? SampleData.currentUser
    }

    // MARK: Derived views of state

    /// PRs for the selected tab, highest priority first (falls back to recency
    /// when verdicts aren't ready / AI is off).
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

    /// The one value the card reads. Defaults sensibly before the map is filled.
    func verdictState(for pr: PullRequest) -> VerdictState {
        verdicts[pr.id] ?? (aiMode == .off ? .off : .loading)
    }

    // MARK: Loading

    func load() async {
        isLoading = true
        loadError = nil
        do {
            pullRequests = try await prProvider.fetchPullRequests()
            isLoading = false
            await recomputeVerdicts()
        } catch {
            loadError = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: Verdicts

    private func recomputeVerdicts() async {
        guard aiMode != .off else {
            for pr in pullRequests { verdicts[pr.id] = .off }
            return
        }

        for pr in pullRequests { verdicts[pr.id] = .loading }

        let engine = verdictEngine
        await withTaskGroup(of: (PullRequest.ID, VerdictState).self) { group in
            for pr in pullRequests {
                group.addTask {
                    do {
                        return (pr.id, .ready(try await engine.verdict(for: pr)))
                    } catch {
                        return (pr.id, .failed("Couldn't analyze this PR."))
                    }
                }
            }
            for await (id, state) in group {
                verdicts[id] = state
            }
        }
    }

    private func priority(of pr: PullRequest) -> Priority {
        if case .ready(let verdict) = verdictState(for: pr) { return verdict.priority }
        return .normal
    }
}
