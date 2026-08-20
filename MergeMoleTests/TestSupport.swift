import Foundation
import Testing
@testable import MergeMole

// The suite's ground rule: every test runs hermetically. Preferences live in a
// throwaway UserDefaults suite, files in the system temp directory, secrets in
// memory, and PRs come from a scripted fake — no test touches the Keychain, the
// network, or anything under ~/Library. This file is the only place that
// machinery lives; the suites just tell stories with it.

// MARK: - Ephemeral state

/// UserDefaults in a throwaway suite. The domain is wiped on creation (stale
/// state from an aborted run) and again when the instance goes away, so no test
/// state outlives its test — and unique names keep parallel tests apart.
final class TempDefaults {
    let defaults: UserDefaults
    private let name: String

    init() {
        name = "app.mergemole.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
    }

    deinit { defaults.removePersistentDomain(forName: name) }
}

/// A scratch file URL in the system temp directory, unique per call.
func tempFileURL(_ name: String) -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("MergeMoleTests-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appendingPathComponent(name)
}

// MARK: - Fakes

/// Scripted PR source. `next(_:)` sets what the following load returns; setting
/// `error` makes the load throw instead. Results are never consumed — a repeated
/// load re-serves the current state, exactly like refetching an unchanged GitHub.
final class FakePRProvider: PRProvider {
    private(set) var fetchCount = 0
    var error: Error?
    private var result = PRFetchResult(viewer: "tester", pullRequests: [])

    func next(_ pullRequests: [PullRequest]) {
        result = PRFetchResult(viewer: "tester", pullRequests: pullRequests)
    }

    func fetchPullRequests(customTabs: [CustomTab]) async throws -> PRFetchResult {
        fetchCount += 1
        if let error { throw error }
        return result
    }
}

/// Recording notifier. Tests assert on what the model *asked for* — banners
/// delivered, sweeps requested — never on UserNotifications itself, which the
/// suite must not touch.
final class FakeNotifier: PRNotifier {
    var prOpened: ((String) -> Void)?
    /// Scripted permission state: set true to simulate a denied permission.
    var denied = false
    private(set) var authorizationRequests = 0
    private(set) var delivered: [PRNotification] = []
    private(set) var removedIDs: [String] = []
    private(set) var removedAllCount = 0

    func requestAuthorization() { authorizationRequests += 1 }
    func deliver(_ notification: PRNotification) { delivered.append(notification) }
    func authorizationDenied() async -> Bool { denied }
    func removeDelivered(ids: [String]) { removedIDs.append(contentsOf: ids) }
    func removeAllDelivered() { removedAllCount += 1 }

    /// Simulate the user clicking a delivered banner (the real notifier would
    /// also open the browser; the model side is what's under test).
    func click(_ id: String) { prOpened?(id) }
}

// MARK: - Builders

extension PRCommit {
    static func real(_ oid: String) -> PRCommit { PRCommit(oid: oid, isMerge: false) }
    static func merge(_ oid: String) -> PRCommit { PRCommit(oid: oid, isMerge: true) }
}

/// A realistic PR with every field defaulted; a test overrides only what it's
/// about, so each call site reads as the scenario's delta from normal.
func makePR(
    id: String = "PR_kwDOAbc001",
    number: Int = 41,
    title: String = "Fix login race on cold start",
    body: String = "Serializes the token refresh so two panels can't race the login flow.",
    repository: String = "acme/checkout",
    author: String = "sam",
    baseBranch: String = "dev",
    head: String = "aaaa111",
    isDraft: Bool = false,
    reviewState: PullRequest.ReviewState = .pending,
    checksState: PullRequest.ChecksState = .passing,
    mergeable: PullRequest.MergeState = .clean,
    comments: Int = 3,
    labels: [String] = ["bug"],
    isArchived: Bool = false,
    commits: [PRCommit] = [.real("aaaa111")],
    relationships: Set<PRRelationship> = [.reviewRequested],
    customTabIDs: Set<UUID> = []
) -> PullRequest {
    var pr = PullRequest(
        id: id,
        number: number,
        title: title,
        body: body,
        repository: repository,
        author: author,
        headBranch: "fix/login-race",
        baseBranch: baseBranch,
        headOID: head,
        isDraft: isDraft,
        reviewState: reviewState,
        checksState: checksState,
        mergeable: mergeable,
        additions: 120,
        deletions: 33,
        changedFiles: 6,
        commentCount: comments,
        resolvedThreads: 0,
        unresolvedThreads: 1,
        labels: labels,
        url: URL(string: "https://github.com/acme/checkout/pull/\(number)")!,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_100_000),
        relationships: relationships
    )
    pr.recentCommits = commits
    pr.isArchived = isArchived
    pr.customTabIDs = customTabIDs
    return pr
}

// MARK: - Model harness

/// One fully-faked AppModel plus the handles a scenario needs to script it.
struct TestWorld {
    let model: AppModel
    let provider: FakePRProvider
    let notifier: FakeNotifier
    let temp: TempDefaults
    let readStoreURL: URL

    var defaults: UserDefaults { temp.defaults }

    /// Script the next fetch and run it through the model.
    func load(_ pullRequests: [PullRequest]) async {
        provider.next(pullRequests)
        await model.load()
    }
}

/// A model wired entirely to fakes. Preferences are preseeded inert (AI off, no
/// refresh scheduler) and, by default, past the first-run seeding so read/unread
/// scenarios start from a clean slate rather than everything seeding read.
/// The preference keys are spelled out on purpose: they're the app's persistence
/// contract, and a failure here on rename means saved settings would break too.
func makeWorld(
    seeded: Bool = true,
    mode: UnreadMode = .activity,
    signals: Set<UnreadSignal>? = nil,
    readStoreURL: URL = tempFileURL("read-state.json"),
    configure: (UserDefaults) -> Void = { _ in }
) -> TestWorld {
    let temp = TempDefaults()
    temp.defaults.set("off", forKey: "aiMode")
    temp.defaults.set("manual", forKey: "refreshInterval")
    temp.defaults.set(mode.rawValue, forKey: "unreadMode")
    if let signals { temp.defaults.set(signals.map(\.rawValue).sorted(), forKey: "unreadSignals") }
    if seeded { temp.defaults.set(true, forKey: "readStateInitialized") }
    configure(temp.defaults)

    let secrets = InMemorySecretStore()
    secrets.set("ghp_test_token", for: .githubToken)   // "connected", so load() proceeds

    let provider = FakePRProvider()
    let notifier = FakeNotifier()
    let model = AppModel(
        prProvider: provider,
        secrets: secrets,
        readStore: ReadStore(fileURL: readStoreURL),
        verdictCache: VerdictCache(fileURL: tempFileURL("verdict-cache.json")),
        notifier: notifier,
        defaults: temp.defaults,
        observesSystemEvents: false
    )
    return TestWorld(model: model, provider: provider, notifier: notifier, temp: temp, readStoreURL: readStoreURL)
}
