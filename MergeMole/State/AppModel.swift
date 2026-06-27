import Foundation
import Observation
import SwiftUI
import AppKit
import Network

/// How the user wants AI to run (chosen in Settings → AI). All three funnel
/// through one `VerdictState` the card branches on, so they stay seamless.
enum AIMode: String, CaseIterable, Identifiable, Sendable {
    case onDevice       // Foundation Models (default)
    case bringYourOwn   // user-supplied key + endpoint (hosted or Ollama)
    case off            // no model; cards collapse to data-only

    var id: String { rawValue }

    /// The radio-card heading in Settings → AI.
    var cardTitle: String {
        switch self {
        case .onDevice:     return "On-device · Apple Intelligence"
        case .bringYourOwn: return "Custom model"
        case .off:          return "Off"
        }
    }

    /// One-line explanation shown under the radio-card heading in Settings.
    var detail: String {
        switch self {
        case .onDevice:     return "Private. Runs locally on this Mac — no PR data leaves your machine."
        case .bringYourOwn: return "Bring your own — OpenAI, Anthropic, or any OpenAI-compatible endpoint."
        case .off:          return "Skip AI triage. MergeMole just lists and organizes your pull requests."
        }
    }
}

/// How often the panel refetches in the background (General → Startup). `.manual`
/// turns the scheduler off — refresh then happens only on open or via the button.
enum RefreshInterval: String, CaseIterable, Identifiable, Sendable {
    case manual, every5, every15, every30, hourly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .manual:  return "Manually"
        case .every5:  return "Every 5 minutes"
        case .every15: return "Every 15 minutes"
        case .every30: return "Every 30 minutes"
        case .hourly:  return "Every hour"
        }
    }

    /// Seconds between refreshes, or nil for manual (no background activity).
    var seconds: TimeInterval? {
        switch self {
        case .manual:  return nil
        case .every5:  return 300
        case .every15: return 900
        case .every30: return 1800
        case .hourly:  return 3600
        }
    }
}

/// A Custom-model provider preset (Providers → AI Triage). Picking one prefills the
/// base URL and selects the wire protocol: OpenAI and "OpenAI-compatible" speak Chat
/// Completions, while "Anthropic" uses Claude's native Messages API.
enum BYOProvider: String, CaseIterable, Identifiable, Sendable {
    case openAI, anthropic, compatible

    var id: String { rawValue }

    var label: String {
        switch self {
        case .openAI:     return "OpenAI"
        case .anthropic:  return "Anthropic"
        case .compatible: return "OpenAI-compatible"
        }
    }

    /// Base URL to prefill when chosen. `nil` for the open-ended case — the user
    /// supplies their own (OpenRouter, Together, Ollama, LM Studio, …).
    var defaultEndpoint: String? {
        switch self {
        case .openAI:     return "https://api.openai.com/v1"
        case .anthropic:  return "https://api.anthropic.com/v1"
        case .compatible: return nil
        }
    }

    /// Placeholder model name for the field — a hint, not a constraint.
    var modelPlaceholder: String {
        switch self {
        case .openAI:     return "gpt-4o-mini"
        case .anthropic:  return "claude-sonnet-4-6"
        case .compatible: return "llama3.1  •  mistral-large"
        }
    }

    /// The wire protocol the engine speaks for this preset.
    var apiFormat: RemoteAPIFormat {
        switch self {
        case .anthropic:          return .anthropic
        case .openAI, .compatible: return .openAI
        }
    }
}

/// Outcome of the Settings "Verify connection" check. Lives on the model (not the
/// view) so it survives the Settings window rebuilding, and resets to `.untested`
/// the moment the endpoint / model / provider changes.
enum BYOStatus: Equatable, Sendable {
    case untested
    case testing
    case ok(model: String)
    case failed(String)
}

/// State of the "what models does this endpoint offer?" lookup that backs the model
/// picker. Best-effort — the model field always accepts a typed value regardless.
enum ModelDiscovery: Equatable, Sendable {
    case idle
    case loading
    case loaded([String])
    case failed(String)
}

/// The panel's backdrop (General → Appearance). Transparent floats content straight
/// over the desktop; Solid is an opaque Flexoki surface for readability over any
/// wallpaper.
enum PanelBackground: String, CaseIterable, Identifiable, Sendable {
    case transparent, solid

    var id: String { rawValue }

    var label: String {
        switch self {
        case .transparent: return "Transparent"
        case .solid:       return "Solid"
        }
    }
}

/// The top-level filters in the panel's tab bar. Most map one-to-one onto a
/// `PRRelationship` — the tab is the presentation layer (title, order, visibility);
/// the relationship is the data. `all` is the exception: it has no single
/// relationship and surfaces every PR that involves you. Order here is the order
/// they appear in the bar.
enum PRTab: String, CaseIterable, Identifiable, Sendable {
    case all
    case reviewRequested
    case assigned
    case created
    case mentioned
    case reviewed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:             return "All"
        case .reviewRequested: return "Review Requested"
        case .assigned:        return "Assigned"
        case .created:         return "Created"
        case .mentioned:       return "Mentioned"
        case .reviewed:        return "Reviewed"
        }
    }

    /// The empty-state line for this tab — why it's clear, plus the auto-refresh
    /// reassurance. Lives next to `title` so a tab's copy stays in one place.
    var emptyMessage: String {
        let lead: String
        switch self {
        case .all:             lead = "No open pull requests involve you right now."
        case .reviewRequested: lead = "No pull requests need your review right now."
        case .assigned:        lead = "No pull requests are assigned to you right now."
        case .created:         lead = "You don't have any open pull requests right now."
        case .mentioned:       lead = "No pull requests mention you right now."
        case .reviewed:        lead = "You're all caught up on reviews right now."
        }
        return "\(lead) New ones will appear here automatically."
    }

    /// The PR relationship this tab surfaces, or `nil` for `all` — which has no
    /// single relationship and matches every PR.
    var relationship: PRRelationship? {
        switch self {
        case .all:             return nil
        case .reviewRequested: return .reviewRequested
        case .assigned:        return .assigned
        case .created:         return .created
        case .mentioned:       return .mentioned
        case .reviewed:        return .reviewed
        }
    }

    /// The identity dot beside the tab in Settings. A fixed hue per tab, distinct
    /// from the brand accent (which means selection, never identity). `all` is the
    /// superset rather than a category, so it takes the neutral primary dot.
    var dotColor: Color {
        switch self {
        case .all:             return .appText
        case .reviewRequested: return .appBlue
        case .assigned:        return .appPurple
        case .created:         return .appGreen
        case .mentioned:       return .appAmber
        case .reviewed:        return .appTextTertiary
        }
    }

    /// The Tabs-list secondary line — describes what the tab collects, so that list
    /// reads as "here's what each tab is for." (The Menu-bar count list uses the
    /// count-led `countSubtitle` instead.)
    var subtitle: String {
        switch self {
        case .all:             return "All PRs involving you"
        case .reviewRequested: return "All PRs awaiting your review"
        case .assigned:        return "All PRs assigned to you"
        case .created:         return "All PRs you opened"
        case .mentioned:       return "All PRs that mention you"
        case .reviewed:        return "All PRs you've reviewed"
        }
    }

    /// The Menu-bar count secondary line — the same descriptors led by this tab's
    /// live count, so each row reads as how much it contributes to the badge. Uses
    /// participle forms ("involving", "mentioning") so they read right at any count.
    func countSubtitle(_ count: Int) -> String {
        let pr = "PR\(count == 1 ? "" : "s")"
        switch self {
        case .all:             return "\(count) \(pr) involving you"
        case .reviewRequested: return "\(count) \(pr) awaiting your review"
        case .assigned:        return "\(count) \(pr) assigned to you"
        case .created:         return "\(count) \(pr) you opened"
        case .mentioned:       return "\(count) \(pr) mentioning you"
        case .reviewed:        return "\(count) \(pr) you've reviewed"
        }
    }

    /// Tabs shown out of the box. All leads, then the day-to-day triage set; the
    /// other two (mentioned, reviewed) are noisier and opt-in via Settings.
    static let defaultVisible: [PRTab] = [.all, .reviewRequested, .assigned, .created]
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

    /// How long an open-panel refresh trusts the last sync before refetching.
    /// Short enough to feel live, long enough that rapid open/close doesn't spam
    /// GitHub. The manual Refresh button ignores it and always refetches.
    private static let staleInterval: TimeInterval = 60

    /// Bumped on each recompute. An in-flight pass re-checks it after every await
    /// and bows out if a newer pass (e.g. the user just switched AI mode) has
    /// superseded it — so a stale engine never writes verdicts over the current one.
    private var recomputeGeneration = 0

    /// Cached so the hot render path (`verdictState`) and `activeEngine` don't
    /// re-probe Foundation Models on every access. Refreshed at the start of each
    /// recompute, so it tracks Apple Intelligence being toggled between refreshes.
    private(set) var onDeviceAvailable = FoundationModelsEngine.isAvailable

    private(set) var currentUser: String
    /// The signed-in user's GitHub avatar, for the Settings connection card. Filled
    /// from the same fetch as the PR list; nil until the first successful load.
    private(set) var currentUserAvatarURL: URL?

    // MARK: PR state

    private(set) var pullRequests: [PullRequest] = []
    private(set) var verdicts: [PullRequest.ID: VerdictState] = [:]
    private(set) var isLoading = false
    private(set) var loadError: String?
    /// When the PR list last loaded successfully — shown in the error state so a
    /// stale list reads as "here's how old this is," not just "it broke."
    private(set) var lastSyncedAt: Date?

    var selectedTab: PRTab = .reviewRequested

    /// The user's tab order (General → Tabs, drag to reorder). Persisted as raw
    /// values; on load we append any tabs a newer version added so they're never
    /// silently dropped, and discard any we no longer ship.
    private(set) var tabOrder: [PRTab] {
        didSet { UserDefaults.standard.set(tabOrder.map(\.rawValue), forKey: Key.tabOrder) }
    }

    /// Tabs the user has hidden in Settings. Persisted; the panel shows the rest.
    /// We store the *hidden* set so a tab added in a future version shows by default
    /// rather than being silently suppressed by an old saved list.
    private(set) var hiddenTabs: Set<PRTab> {
        didSet {
            UserDefaults.standard.set(hiddenTabs.map(\.rawValue), forKey: Key.hiddenTabs)
            // Never strand the selection on a tab that's no longer shown.
            if hiddenTabs.contains(selectedTab), let first = visibleTabs.first {
                selectedTab = first
            }
        }
    }

    /// Tabs the panel shows, in the user's order.
    var visibleTabs: [PRTab] { tabOrder.filter { !hiddenTabs.contains($0) } }

    /// Every tab in the user's order — the Settings list (shown *and* hidden).
    var orderedTabs: [PRTab] { tabOrder }

    /// Show/hide a tab. Refuses to hide the last visible one — the bar always has
    /// at least one tab.
    func setTab(_ tab: PRTab, visible: Bool) {
        if visible {
            hiddenTabs.remove(tab)
        } else if hiddenTabs.count < PRTab.allCases.count - 1 {
            hiddenTabs.insert(tab)
        }
    }

    /// Reorder by dropping `dragged` onto `target`'s slot (called live during a
    /// Settings drag). Mirrors `List.onMove` index math so the row lands where the
    /// cursor is, whether it moved up or down.
    func moveTab(_ dragged: PRTab, to target: PRTab) {
        guard dragged != target,
              let from = tabOrder.firstIndex(of: dragged),
              let to = tabOrder.firstIndex(of: target) else { return }
        tabOrder.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
    }

    /// Which groups feed the menu-bar count (General → Menu-bar count). Stored as
    /// raw values; defaults to Review Requested. The badge totals the deduped union
    /// of PRs across these groups, independent of which tabs the panel shows.
    private(set) var badgeTabs: Set<PRTab> {
        didSet { UserDefaults.standard.set(badgeTabs.map(\.rawValue), forKey: Key.badgeTabs) }
    }

    /// Include/exclude a group from the menu-bar count. Any subset is allowed —
    /// selecting none simply shows no number (just the empty-burrow icon).
    func setBadge(_ tab: PRTab, on: Bool) {
        if on { badgeTabs.insert(tab) } else { badgeTabs.remove(tab) }
    }

    // MARK: Persisted preferences

    var aiMode: AIMode {
        didSet {
            guard aiMode != oldValue else { return }
            UserDefaults.standard.set(aiMode.rawValue, forKey: Key.aiMode)
            Task { await recomputeVerdicts() }
        }
    }

    // MVP: a single Custom-model connection — one endpoint + one model + one key.
    // Switching provider clears all three (see `switchProvider`), so there's never a
    // mismatched key/model to reason about. Endpoint + model live in UserDefaults;
    // the key goes through `secrets` (Keychain).

    var byoEndpoint: String {
        didSet {
            UserDefaults.standard.set(byoEndpoint, forKey: Key.byoEndpoint)
            byoStatus = .untested
            modelDiscovery = .idle
        }
    }

    /// Editing the model invalidates a prior test result.
    var byoModel: String {
        didSet {
            UserDefaults.standard.set(byoModel, forKey: Key.byoModel)
            byoStatus = .untested
        }
    }

    /// The provider preset. Don't set this directly to change provider — go through
    /// `switchProvider(to:)`, which also clears the single key/model/endpoint. The
    /// didSet only persists the value and resets transient state.
    var byoProvider: BYOProvider {
        didSet {
            guard byoProvider != oldValue else { return }
            UserDefaults.standard.set(byoProvider.rawValue, forKey: Key.byoProvider)
            byoStatus = .untested
            modelDiscovery = .idle
        }
    }

    /// Verification outcome for the current Custom-model config (Settings only).
    private(set) var byoStatus: BYOStatus = .untested

    /// The models the configured endpoint advertises (Settings model picker).
    private(set) var modelDiscovery: ModelDiscovery = .idle

    /// How often the background scheduler refetches. Changing it reschedules.
    var refreshInterval: RefreshInterval {
        didSet {
            guard refreshInterval != oldValue else { return }
            UserDefaults.standard.set(refreshInterval.rawValue, forKey: Key.refreshInterval)
            startAutoRefresh()
        }
    }

    /// The panel backdrop (glass / transparent / solid). Persisted; the panel reads
    /// it live, so switching in Settings re-skins the open panel immediately.
    var panelBackground: PanelBackground {
        didSet {
            guard panelBackground != oldValue else { return }
            UserDefaults.standard.set(panelBackground.rawValue, forKey: Key.panelBackground)
        }
    }

    private(set) var isGitHubConnected: Bool

    /// UserDefaults keys for the app's non-secret preferences. These live in
    /// `~/Library/Application Support/../Preferences/app.mergemole.MergeMole.plist`
    /// (the standard domain). Secrets are NOT here — they go through `secrets`
    /// (Keychain); see `SecretKey`. `resetAll()` wipes this whole domain.
    private enum Key {
        static let aiMode = "aiMode"
        static let byoEndpoint = "byoEndpoint"
        static let byoModel = "byoModel"
        static let byoProvider = "byoProvider"
        static let refreshInterval = "refreshInterval"
        static let panelBackground = "panelBackground"
        static let hiddenTabs = "hiddenTabs"
        static let tabOrder = "tabOrder"
        static let badgeTabs = "badgeTabs"
    }

    // MARK: Init

    init(
        prProvider: PRProvider? = nil,
        verdictEngine: VerdictEngine? = nil,
        secrets: SecretStore? = nil,
        currentUser: String? = nil
    ) {
        let secrets = secrets ?? KeychainSecretStore()
        self.prProvider = prProvider ?? GitHubPRProvider(secrets: secrets)
        self.injectedEngine = verdictEngine
        self.secrets = secrets
        self.currentUser = currentUser ?? SampleData.currentUser

        let defaults = UserDefaults.standard
        self.aiMode = AIMode(rawValue: defaults.string(forKey: Key.aiMode) ?? "") ?? .onDevice
        self.byoEndpoint = defaults.string(forKey: Key.byoEndpoint) ?? ""
        self.byoModel = defaults.string(forKey: Key.byoModel) ?? ""
        self.byoProvider = BYOProvider(rawValue: defaults.string(forKey: Key.byoProvider) ?? "") ?? .openAI
        self.refreshInterval = RefreshInterval(rawValue: defaults.string(forKey: Key.refreshInterval) ?? "") ?? .every15
        self.panelBackground = PanelBackground(rawValue: defaults.string(forKey: Key.panelBackground) ?? "") ?? .transparent
        self.isGitHubConnected = secrets.string(for: .githubToken) != nil

        // Restore the saved tab order, appending any tabs added since (so a newer
        // build's tabs still appear) and dropping any we no longer ship.
        if let savedOrder = defaults.array(forKey: Key.tabOrder) as? [String] {
            let restored = savedOrder.compactMap(PRTab.init(rawValue:))
            let added = PRTab.allCases.filter { !restored.contains($0) }
            // New tabs normally append; All is the top-level "everything" view, so
            // it leads even for users upgrading from a build that predates it.
            self.tabOrder = added.filter { $0 == .all } + restored + added.filter { $0 != .all }
        } else {
            self.tabOrder = PRTab.allCases
        }

        // No saved list (first launch / fresh install) → hide the opt-in tabs;
        // otherwise honor exactly what the user chose.
        if let saved = defaults.array(forKey: Key.hiddenTabs) as? [String] {
            self.hiddenTabs = Set(saved.compactMap(PRTab.init(rawValue:)))
        } else {
            self.hiddenTabs = Set(PRTab.allCases).subtracting(PRTab.defaultVisible)
        }

        // Which groups feed the menu-bar count; default to Review Requested.
        // (Set before the guard below, which reads computed props needing full init.)
        if let savedBadge = defaults.array(forKey: Key.badgeTabs) as? [String] {
            self.badgeTabs = Set(savedBadge.compactMap(PRTab.init(rawValue:)))
        } else {
            self.badgeTabs = [.reviewRequested]
        }

        if hiddenTabs.contains(selectedTab) {
            selectedTab = visibleTabs.first ?? .reviewRequested
        }

        // Background freshness: periodic refetch + refresh on wake / network return.
        observeSystemEvents()
        startAutoRefresh()
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
            startAutoRefresh()   // now that we're connected, arm the periodic refetch
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
        currentUserAvatarURL = nil
        loadError = nil
        startAutoRefresh()   // cancels the scheduler (no-op while disconnected)
    }

    // MARK: BYO API key (non-displayed; lives in Keychain — one slot for the MVP)

    var byoAPIKey: String { secrets.string(for: .remoteModelAPIKey) ?? "" }

    func setBYOAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        secrets.set(trimmed.isEmpty ? nil : trimmed, for: .remoteModelAPIKey)
    }

    /// Whether a key is stored — drives the "key saved" hint without ever reading the
    /// secret back into the UI.
    var hasBYOKey: Bool { !byoAPIKey.isEmpty }

    /// BYO is wired for triage: an endpoint and a model, plus a key for the hosted
    /// providers (local endpoints need none). Drives the "Connected" indicator and
    /// persists across launches, so a returning user sees it immediately.
    var byoReady: Bool {
        byoConfigured && (byoProvider == .compatible || hasBYOKey)
    }

    /// Forget the saved key + model and reset state — a full disconnect. The endpoint
    /// keeps its preset so reconnecting is one step.
    func clearBYOConnection() {
        setBYOAPIKey("")
        byoModel = ""
        byoStatus = .untested
        modelDiscovery = .idle
    }

    /// Switch provider, clearing the single saved key + model (the MVP keeps exactly
    /// one connection). The endpoint resets to the new provider's preset — blank for
    /// the open-ended "compatible" case, which the user fills in.
    func switchProvider(to provider: BYOProvider) {
        setBYOAPIKey("")
        byoModel = ""
        byoProvider = provider
        byoEndpoint = provider.defaultEndpoint ?? ""
        byoStatus = .untested
        modelDiscovery = .idle
    }

    // MARK: Reset

    /// Factory reset — wipe everything the app has persisted and return the live
    /// state to first-launch defaults. With no GitHub token, the panel drops back to
    /// its connect screen, so this is the full "start over."
    ///
    /// Storage map (everything the app writes; this clears all of it):
    ///   • Keychain (`app.mergemole.MergeMole`) — GitHub token + BYO API key.
    ///   • UserDefaults (`~/Library/Preferences/app.mergemole.MergeMole.plist`) —
    ///     aiMode, byoProvider/Endpoint/Model, refreshInterval, panelBackground,
    ///     tabOrder/hiddenTabs/badgeTabs, checkForUpdates (@AppStorage).
    ///   • Application Support (`…/Application Support/MergeMole/verdict-cache.json`) —
    ///     the AI verdict cache.
    ///   • Login item (SMAppService) — launch-at-login registration.
    func resetAll() {
        // 1. Live state → defaults, so any open window updates immediately.
        disconnectGitHub()                  // token + PR state + scheduler
        lastSyncedAt = nil
        aiMode = .onDevice
        byoProvider = .openAI
        byoEndpoint = ""
        byoModel = ""
        byoStatus = .untested
        modelDiscovery = .idle
        refreshInterval = .every15
        panelBackground = .transparent
        tabOrder = PRTab.allCases
        hiddenTabs = Set(PRTab.allCases).subtracting(PRTab.defaultVisible)
        badgeTabs = [.reviewRequested]
        selectedTab = .reviewRequested

        // 2. Keychain — every slot we own.
        for key in SecretKey.allCases { secrets.set(nil, for: key) }

        // 3. Verdict cache file.
        verdictCache.clear()

        // 4. Launch-at-login registration.
        LoginItem.set(false)

        // 5. Wipe the whole UserDefaults domain last — after the didSets above, so
        //    nothing is left behind, and this also sweeps @AppStorage values and any
        //    keys from earlier builds.
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
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
        guard let relationship = tab.relationship else { return pullRequests }
        return pullRequests.filter { $0.relationships.contains(relationship) }
    }

    var tabCounts: [PRTab: Int] {
        Dictionary(uniqueKeysWithValues: PRTab.allCases.map { ($0, pullRequests(for: $0).count) })
    }

    /// PRs in the groups the user picked for the count (`badgeTabs`, default Review
    /// Requested), deduped across groups and independent of which tabs the panel
    /// shows. The basis for both the count and its priority.
    private var badgePullRequests: [PullRequest] {
        pullRequests.filter { pr in
            badgeTabs.contains { tab in
                guard let relationship = tab.relationship else { return true }
                return pr.relationships.contains(relationship)
            }
        }
    }

    /// The number on the menu-bar icon and beside the panel-header brand. No groups
    /// selected → no number.
    var badgeCount: Int { badgePullRequests.count }

    /// The most urgent priority among the counted PRs — colors the panel-header
    /// count (amber for high, red for urgent). `nil` when nothing is counted.
    var badgePriority: Priority? { badgePullRequests.map { priority(of: $0) }.max() }

    func verdictState(for pr: PullRequest) -> VerdictState {
        verdicts[pr.id] ?? (aiEnabled ? .loading : .off)
    }

    /// Whether verdicts should compute at all. Mirrors `activeEngine != nil` but
    /// builds no engine and probes no framework, so it's safe to call while views
    /// render — `activeEngine` constructs an engine and must stay off that path.
    private var aiEnabled: Bool {
        switch aiMode {
        case .off:          return false
        case .onDevice:     return injectedEngine != nil || onDeviceAvailable
        case .bringYourOwn: return injectedEngine != nil || byoConfigured
        }
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
            return onDeviceAvailable ? FoundationModelsEngine() : nil
        case .bringYourOwn:
            if let injectedEngine { return injectedEngine }
            guard byoConfigured else { return nil }
            return RemoteVerdictEngine(
                endpoint: byoEndpoint.trimmingCharacters(in: .whitespaces),
                model: byoModel.trimmingCharacters(in: .whitespaces),
                apiKey: byoAPIKey,
                format: byoProvider.apiFormat
            )
        }
    }

    /// Identifies which engine produced a verdict, so the cache keeps them
    /// separate (switching engines re-evaluates rather than serving stale output).
    private var engineTag: String {
        // Bump when the prompt or output contract changes materially, so verdicts
        // cached under an older prompt are re-run rather than served stale.
        let version = "v3"   // v3: merge-conflict signal added to the prompt
        switch aiMode {
        case .off:          return "off"
        case .onDevice:     return "ondevice@\(version)"
        case .bringYourOwn: return "byo:\(byoProvider.rawValue):\(byoModel)@\(version)"
        }
    }

    /// On-device AI was chosen but this Mac can't run it (Intel, or Apple
    /// Intelligence off). Surfaced in Settings; cards fall back to data-only.
    var onDeviceUnavailable: Bool {
        aiMode == .onDevice && injectedEngine == nil && !onDeviceAvailable
    }

    /// BYO has both an endpoint and a model name (the minimum to run).
    var byoConfigured: Bool {
        !byoEndpoint.trimmingCharacters(in: .whitespaces).isEmpty
            && !byoModel.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Verify the BYO endpoint/model/key (for the Settings "Verify" button).
    /// Returns nil on success, or an error message.
    func testRemoteModel() async -> String? {
        guard byoConfigured else { return "Enter an endpoint and model first." }
        let engine = RemoteVerdictEngine(
            endpoint: byoEndpoint.trimmingCharacters(in: .whitespaces),
            model: byoModel.trimmingCharacters(in: .whitespaces),
            apiKey: byoAPIKey,
            format: byoProvider.apiFormat
        )
        do {
            try await engine.validate()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Run the verify check and, on success, re-triage with the new engine. Drives
    /// the Settings "Verify connection" button; the outcome persists in `byoStatus`
    /// so the form reflects it until the config changes.
    func verifyBYO() async {
        byoStatus = .testing
        if let error = await testRemoteModel() {
            byoStatus = .failed(error)
        } else {
            byoStatus = .ok(model: byoModel.trimmingCharacters(in: .whitespaces))
            await refreshVerdicts()
        }
    }

    /// Drop the connection back to "not connected" — the fetched model list and any
    /// test result no longer reflect the current credentials. Called when the API key
    /// is edited, so the model picker re-locks until the user reconnects.
    func resetBYOConnection() {
        modelDiscovery = .idle
        byoStatus = .untested
    }

    /// Ask the endpoint which models it offers (`GET /v1/models`) and stash the
    /// result in `modelDiscovery` for the Settings model picker. `typedKey` lets the
    /// form pass a key the user has entered but not yet saved, so discovery works
    /// during first-time setup. Failures are non-fatal — the field still takes a
    /// typed value.
    func discoverModels(typedKey: String = "") async {
        let endpoint = byoEndpoint.trimmingCharacters(in: .whitespaces)
        guard !endpoint.isEmpty else { modelDiscovery = .idle; return }
        modelDiscovery = .loading
        let key = typedKey.isEmpty ? byoAPIKey : typedKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let engine = RemoteVerdictEngine(
            endpoint: endpoint,
            model: byoModel.trimmingCharacters(in: .whitespaces),
            apiKey: key,
            format: byoProvider.apiFormat
        )
        do {
            let models = try await engine.availableModels()
            modelDiscovery = .loaded(models.sorted())
        } catch {
            modelDiscovery = .failed(error.localizedDescription)
        }
    }

    /// Re-run verdicts with the current engine (e.g. after BYO config changes).
    func refreshVerdicts() async {
        await recomputeVerdicts()
    }

    // MARK: Background refresh

    /// Energy-aware periodic refetch. `NSBackgroundActivityScheduler` lets macOS
    /// pick the moment (coalesced with other wakeups, deferred under Low Power /
    /// thermal pressure) instead of us firing a hard timer — the right tool for a
    /// menu-bar agent polling every few minutes. Recreated when the interval
    /// changes; nil while set to Manually or disconnected.
    private var refreshScheduler: NSBackgroundActivityScheduler?

    /// Watches connectivity so a refetch fires the moment the network returns,
    /// rather than waiting for the next scheduled tick.
    private let pathMonitor = NWPathMonitor()
    private var wasOffline = false

    /// (Re)arm the periodic refresh for the current interval. A no-op (and cancel)
    /// while disconnected or set to Manually.
    func startAutoRefresh() {
        refreshScheduler?.invalidate()
        refreshScheduler = nil
        guard isGitHubConnected, let seconds = refreshInterval.seconds else { return }

        let scheduler = NSBackgroundActivityScheduler(identifier: "app.mergemole.refresh")
        scheduler.repeats = true
        scheduler.interval = seconds
        scheduler.tolerance = min(seconds * 0.2, 300)   // slack so macOS can batch the wakeup
        scheduler.qualityOfService = .utility
        scheduler.schedule { [weak self] completion in
            // Fired on a background queue at a system-chosen time; hop to the main
            // actor to read model state and run the fetch.
            Task { @MainActor in
                if let self, self.isGitHubConnected, !self.isLoading { await self.load() }
                completion(.finished)
            }
        }
        refreshScheduler = scheduler
    }

    /// Refresh on wake and when connectivity is restored — the two moments a stale
    /// list is most likely and the next scheduled tick may still be far off.
    private func observeSystemEvents() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.loadIfStale() }
        }

        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let online = path.status == .satisfied
                if online, self.wasOffline, self.isGitHubConnected { await self.load() }
                self.wasOffline = !online
            }
        }
        pathMonitor.start(queue: DispatchQueue.global(qos: .utility))
    }

    // MARK: Loading

    /// The auto-refresh that fires when the panel opens. Skips the fetch if a load
    /// is already in flight, or if we synced within `staleInterval` — so reopening
    /// repeatedly stays cheap. Manual Refresh calls `load()` directly to force one.
    func loadIfStale() async {
        guard !isLoading else { return }
        if let synced = lastSyncedAt, Date.now.timeIntervalSince(synced) < Self.staleInterval {
            // The list is fresh, but a previous open may have been closed mid-analysis.
            // Resume any verdicts still pending — no network, just the model.
            if hasPendingVerdicts { await recomputeVerdicts() }
            return
        }
        await load()
    }

    /// Any visible PR still waiting on a verdict — e.g. analysis was cut short when
    /// the panel closed. Lets a fresh reopen finish the work without refetching.
    private var hasPendingVerdicts: Bool {
        pullRequests.contains { pr in
            if case .loading = verdictState(for: pr) { return true }
            return false
        }
    }

    func load() async {
        guard !isLoading else { return }           // one fetch at a time, whoever calls
        guard isGitHubConnected else { return }    // RootView shows the connect state
        isLoading = true
        loadError = nil
        do {
            let result = try await prProvider.fetchPullRequests()
            if let viewer = result.viewer { currentUser = viewer }
            if let avatar = result.viewerAvatarURL { currentUserAvatarURL = avatar }
            pullRequests = result.pullRequests
            lastSyncedAt = .now
            isLoading = false
            await recomputeVerdicts()
        } catch {
            loadError = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: Verdicts

    private func recomputeVerdicts() async {
        onDeviceAvailable = FoundationModelsEngine.isAvailable   // refresh before we resolve
        recomputeGeneration += 1
        let generation = recomputeGeneration

        guard let engine = activeEngine else {
            for pr in pullRequests { verdicts[pr.id] = .off }
            return
        }

        // Serve unchanged PRs straight from cache; only run the model on the
        // ones whose content signature changed (or are new).
        let tag = engineTag
        var stale: [PullRequest] = []
        for pr in pullRequests {
            if let cached = verdictCache.verdict(for: pr, engine: tag) {
                verdicts[pr.id] = .ready(cached)
            } else {
                verdicts[pr.id] = .loading
                stale.append(pr)
            }
        }

        var stored = false
        if !stale.isEmpty {
            // Bounded concurrency: the on-device model shouldn't be hit with dozens
            // of requests at once. Cards fill in as each verdict lands.
            await withTaskGroup(of: (PullRequest, VerdictState).self) { group in
                var next = 0
                func schedule() {
                    // Stop feeding the model once this pass is cancelled (the panel
                    // closed): in-flight verdicts still finish and cache, but nothing
                    // new starts — a cold boot doesn't burn 25 analyses you closed on.
                    guard !Task.isCancelled, next < stale.count else { return }
                    let pr = stale[next]
                    next += 1
                    group.addTask {
                        do { return (pr, .ready(try await engine.verdict(for: pr))) }
                        catch { return (pr, .failed("Couldn't analyze this PR.")) }
                    }
                }
                for _ in 0..<min(Self.maxConcurrentVerdicts, stale.count) { schedule() }
                for await (pr, state) in group {
                    // A newer recompute superseded us (mode/config changed): drain the
                    // in-flight tasks without writing, and schedule no more.
                    guard generation == recomputeGeneration else { continue }
                    verdicts[pr.id] = state
                    if case .ready(let verdict) = state {
                        verdictCache.store(verdict, for: pr, engine: tag)
                        stored = true
                    }
                    schedule()
                }
            }
            guard generation == recomputeGeneration else { return }
        }

        // Forget PRs that are gone (closed/merged), then save — but only when the
        // cache actually changed, so a fully-cached reopen does no disk write.
        let pruned = verdictCache.prune(toCurrent: pullRequests)
        if stored || pruned { verdictCache.persist() }
    }

    private func priority(of pr: PullRequest) -> Priority {
        if case .ready(let verdict) = verdictState(for: pr) { return verdict.priority }
        return .normal
    }
}
