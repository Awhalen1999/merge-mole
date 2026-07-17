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
    case manual, every1, every5, every15, every30, hourly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .manual:  return "Manually"
        case .every1:  return "Every minute"
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
        case .every1:  return 60
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
    case solid, transparent   // order drives the Settings segmented control

    var id: String { rawValue }

    var label: String {
        switch self {
        case .transparent: return "Transparent"
        case .solid:       return "Solid"
        }
    }
}

/// How dense each PR card renders (General → Appearance). Both show the same
/// data; Compact drops the avatar and steps down the paddings and type sizes.
enum CardDensity: String, CaseIterable, Identifiable, Sendable {
    case detailed, compact   // order drives the Settings segmented control

    var id: String { rawValue }

    var label: String {
        switch self {
        case .detailed: return "Detailed"
        case .compact:  return "Compact"
        }
    }
}

/// The Settings window's tabs. Shared so the panel's ⋮ menu can deep-link to one
/// (e.g. "About MergeMole" opens straight to About) instead of a separate window.
enum SettingsTab: String, CaseIterable, Identifiable, Sendable {
    case general, tabs, providers, about
    var id: String { rawValue }
}

/// The top-level filters in the panel's tab bar. The six built-ins are a thin
/// presentation layer over the relationships each PR carries; `custom` is a
/// user-defined tab — a saved GitHub search — referenced by id, with its
/// definition (name + query) living in `AppModel.customTabs`. Membership is the
/// data either way: see `matches(_:)`. Copy that depends on the saved definition
/// (title, subtitle) resolves through the model; everything below is fixed per case.
enum PRTab: Hashable, Identifiable, Sendable {
    case all
    case reviewRequested
    case assigned
    case created
    case mentioned
    case reviewed
    case custom(UUID)

    /// The built-in tabs, in their default bar order. (`CaseIterable` can't cover
    /// the associated-value case; the full list including custom tabs is the
    /// model's `orderedTabs`.)
    static let builtin: [PRTab] = [.all, .reviewRequested, .assigned, .created, .mentioned, .reviewed]

    var id: String { rawValue }

    /// Whether this tab shows the PR. Built-ins read the relationship buckets
    /// GitHub returned it under; a custom tab reads the saved searches that
    /// matched it. `all` is the superset — every PR in any of your tabs.
    func matches(_ pr: PullRequest) -> Bool {
        switch self {
        case .all:             return true
        case .reviewRequested: return pr.relationships.contains(.reviewRequested)
        case .assigned:        return pr.relationships.contains(.assigned)
        case .created:         return pr.relationships.contains(.created)
        case .mentioned:       return pr.relationships.contains(.mentioned)
        case .reviewed:        return pr.relationships.contains(.reviewed)
        case .custom(let id):  return pr.customTabIDs.contains(id)
        }
    }

    /// The empty-state line for this tab — why it's clear, plus the auto-refresh
    /// reassurance. Custom tabs share one line; their specifics live in the query.
    var emptyMessage: String {
        let lead: String
        switch self {
        case .all:             lead = "No open pull requests involve you right now."
        case .reviewRequested: lead = "No pull requests need your review right now."
        case .assigned:        lead = "No pull requests are assigned to you right now."
        case .created:         lead = "You don't have any open pull requests right now."
        case .mentioned:       lead = "No pull requests mention you right now."
        case .reviewed:        lead = "You're all caught up on reviews right now."
        case .custom:          lead = "No pull requests match this search right now."
        }
        return "\(lead) New ones will appear here automatically."
    }

    /// The identity dot beside the tab in Settings. A fixed hue per tab, distinct
    /// from the brand accent (which means selection, never identity). `all` is the
    /// superset rather than a category, so it takes the neutral primary dot;
    /// custom tabs share cyan — "yours" is itself a category.
    var dotColor: Color {
        switch self {
        case .all:             return .appText
        case .reviewRequested: return .appBlue
        case .assigned:        return .appPurple
        case .created:         return .appGreen
        case .mentioned:       return .appAmber
        case .reviewed:        return .appTextTertiary
        case .custom:          return .appCyan
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
        case .custom:          return "\(count) \(pr) matching this search"
        }
    }

    /// Tabs shown out of the box. All leads, then the day-to-day triage set; the
    /// other two (mentioned, reviewed) are noisier and opt-in via Settings.
    static let defaultVisible: [PRTab] = [.all, .reviewRequested, .assigned, .created]
}

/// String raw values for persistence (tab order, hidden set, badge set). The
/// built-ins keep their original raw strings so saved preferences from earlier
/// builds load unchanged; a custom tab encodes as `custom:<uuid>`.
extension PRTab: RawRepresentable {
    init?(rawValue: String) {
        if let builtin = Self.builtin.first(where: { $0.rawValue == rawValue }) {
            self = builtin
        } else if rawValue.hasPrefix("custom:"),
                  let id = UUID(uuidString: String(rawValue.dropFirst("custom:".count))) {
            self = .custom(id)
        } else {
            return nil
        }
    }

    var rawValue: String {
        switch self {
        case .all:             return "all"
        case .reviewRequested: return "reviewRequested"
        case .assigned:        return "assigned"
        case .created:         return "created"
        case .mentioned:       return "mentioned"
        case .reviewed:        return "reviewed"
        case .custom(let id):  return "custom:\(id.uuidString)"
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
    private let readStore = ReadStore()

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
    private(set) var onDeviceAvailability = OnDeviceModel.availability

    /// True while the menu-bar panel is open. Verdicts run the model only when the
    /// user is actually looking: background fetches still refresh the list and the
    /// badge, but the on-device model never spins up behind a closed panel — so an
    /// idle menu-bar app stays genuinely idle (no RAM, no Neural Engine, no battery).
    private(set) var isPanelOpen = false

    private(set) var currentUser: String
    /// The signed-in user's GitHub avatar, for the Settings connection card. Filled
    /// from the same fetch as the PR list; nil until the first successful load.
    private(set) var currentUserAvatarURL: URL?

    // MARK: PR state

    private(set) var pullRequests: [PullRequest] = []
    private(set) var verdicts: [PullRequest.ID: VerdictState] = [:]
    /// Read/unread state: PR id → the content signature when last marked read. The
    /// observed in-memory map (the disk copy lives in `readStore`). A PR is unread
    /// when its entry is missing or no longer matches its current signature.
    private(set) var readSignatures: [String: String] = [:]
    private(set) var isLoading = false
    private(set) var loadError: String?
    /// When the PR list last loaded successfully — shown in the error state so a
    /// stale list reads as "here's how old this is," not just "it broke."
    private(set) var lastSyncedAt: Date?

    var selectedTab: PRTab = .reviewRequested

    /// Which Settings tab to show. Transient (not persisted) — set by the ⋮ menu so
    /// "About MergeMole" can open Settings straight to About.
    var settingsTab: SettingsTab = .general

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
    /// The invariant: always exactly the built-ins plus every custom tab.
    var orderedTabs: [PRTab] { tabOrder }

    /// Show/hide a tab. Refuses to hide the last visible one — the bar always has
    /// at least one tab.
    func setTab(_ tab: PRTab, visible: Bool) {
        if visible {
            hiddenTabs.remove(tab)
        } else if hiddenTabs.count < tabOrder.count - 1 {
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

    // MARK: Custom tabs

    /// The user's saved custom tabs (Settings → Tabs → New Tab), each a named
    /// GitHub search. Persisted as JSON next to the other preferences; the panel
    /// treats them exactly like the built-ins via `PRTab.custom(id)`.
    private(set) var customTabs: [CustomTab] {
        didSet {
            if let data = try? JSONEncoder().encode(customTabs) {
                UserDefaults.standard.set(data, forKey: Key.customTabs)
            }
        }
    }

    /// A custom tab's saved definition — nil once it's been deleted.
    func customTab(_ id: UUID) -> CustomTab? {
        customTabs.first { $0.id == id }
    }

    /// Create a tab from a name + search, show it at the end of the bar, and jump
    /// the panel to it — then fetch so it fills in right away.
    func addCustomTab(name: String, query: String) {
        let tab = CustomTab(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            query: query.trimmingCharacters(in: .whitespacesAndNewlines))
        customTabs.append(tab)
        tabOrder.append(.custom(tab.id))
        selectedTab = .custom(tab.id)
        Task { await load() }
    }

    /// Rewrite a tab's name and/or search. A changed search refetches (the old
    /// matches are stale); a pure rename touches nothing but the label.
    func updateCustomTab(_ id: UUID, name: String, query: String) {
        guard let index = customTabs.firstIndex(where: { $0.id == id }) else { return }
        var tab = customTabs[index]
        let queryChanged = tab.query != query.trimmingCharacters(in: .whitespacesAndNewlines)
        tab.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        tab.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        customTabs[index] = tab   // one mutation → one persist
        if queryChanged { Task { await load() } }
    }

    /// Delete a tab: drop its definition and every reference to it (order, hidden,
    /// badge, selection), then shed its matches so PRs only that search pulled in
    /// don't linger under All until the next fetch.
    func removeCustomTab(_ id: UUID) {
        customTabs.removeAll { $0.id == id }
        let tab = PRTab.custom(id)
        tabOrder.removeAll { $0 == tab }
        hiddenTabs.remove(tab)
        badgeTabs.remove(tab)
        if selectedTab == tab { selectedTab = visibleTabs.first ?? .all }
        for index in pullRequests.indices { pullRequests[index].customTabIDs.remove(id) }
        pullRequests.removeAll { $0.relationships.isEmpty && $0.customTabIDs.isEmpty }
    }

    // MARK: Tab display

    // A tab's title and subtitle are the only copy that reads the user's saved
    // definition, so they resolve here; everything fixed per case (dot, counts,
    // empty state) lives on `PRTab` itself.

    func title(for tab: PRTab) -> String {
        switch tab {
        case .all:             return "All"
        case .reviewRequested: return "Review Requested"
        case .assigned:        return "Assigned"
        case .created:         return "Created"
        case .mentioned:       return "Mentioned"
        case .reviewed:        return "Reviewed"
        case .custom(let id):  return customTab(id)?.name ?? "Custom"
        }
    }

    /// The Tabs-list secondary line — what the tab collects, so that list reads as
    /// "here's what each tab is for." A custom tab shows its search verbatim — the
    /// query *is* the tab's definition, and seeing it makes a typo easy to spot.
    func subtitle(for tab: PRTab) -> String {
        switch tab {
        case .all:             return "All PRs involving you"
        case .reviewRequested: return "All PRs awaiting your review"
        case .assigned:        return "All PRs assigned to you"
        case .created:         return "All PRs you opened"
        case .mentioned:       return "All PRs that mention you"
        case .reviewed:        return "All PRs you've reviewed"
        case .custom(let id):  return customTab(id)?.query ?? ""
        }
    }

    // MARK: Persisted preferences

    var aiMode: AIMode {
        didSet {
            guard aiMode != oldValue else { return }
            UserDefaults.standard.set(aiMode.rawValue, forKey: Key.aiMode)
            Task { await recomputeVerdicts() }
        }
    }

    // A single Custom-model connection — one endpoint + one model + one key.
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

    /// Detailed vs compact PR cards. Persisted; cards read it live, so switching
    /// in Settings reflows the open panel immediately.
    var cardDensity: CardDensity {
        didSet {
            guard cardDensity != oldValue else { return }
            UserDefaults.standard.set(cardDensity.rawValue, forKey: Key.cardDensity)
        }
    }

    private(set) var isGitHubConnected: Bool

    /// Set when GitHub rejected the stored token (expired/revoked) mid-session, so the
    /// connect screen can say "reconnect" with context instead of a bare first-run prompt.
    private(set) var tokenRejected = false

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
        static let cardDensity = "cardDensity"
        static let hiddenTabs = "hiddenTabs"
        static let tabOrder = "tabOrder"
        static let badgeTabs = "badgeTabs"
        static let customTabs = "customTabs"
        static let readStateInitialized = "readStateInitialized"
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
        self.panelBackground = PanelBackground(rawValue: defaults.string(forKey: Key.panelBackground) ?? "") ?? .solid
        self.cardDensity = CardDensity(rawValue: defaults.string(forKey: Key.cardDensity) ?? "") ?? .detailed
        self.isGitHubConnected = secrets.string(for: .githubToken) != nil
        self.readSignatures = readStore.load()

        // Custom tabs load first: they define which `custom:` raws in the saved
        // order / hidden / badge lists still point at a live definition.
        let customTabs = Self.loadCustomTabs(defaults)
        self.customTabs = customTabs
        let knownTabs = PRTab.builtin + customTabs.map { PRTab.custom($0.id) }

        // Restore the saved tab order, appending any tabs added since (so a newer
        // build's tabs and freshly-defined customs still appear) and dropping any
        // we no longer ship — including custom tabs whose definition is gone.
        // Deduped defensively: `tabCounts` and friends key dictionaries by these.
        if let savedOrder = defaults.array(forKey: Key.tabOrder) as? [String] {
            var seen = Set<PRTab>()
            let restored = savedOrder.compactMap(PRTab.init(rawValue:))
                .filter { knownTabs.contains($0) && seen.insert($0).inserted }
            let added = knownTabs.filter { !seen.contains($0) }
            // New tabs normally append; All is the top-level "everything" view, so
            // it leads even for users upgrading from a build that predates it.
            self.tabOrder = added.filter { $0 == .all } + restored + added.filter { $0 != .all }
        } else {
            self.tabOrder = knownTabs
        }

        // No saved list (first launch / fresh install) → hide the opt-in tabs;
        // otherwise honor exactly what the user chose.
        if let saved = defaults.array(forKey: Key.hiddenTabs) as? [String] {
            self.hiddenTabs = Set(saved.compactMap(PRTab.init(rawValue:))).intersection(knownTabs)
        } else {
            self.hiddenTabs = Set(PRTab.builtin).subtracting(PRTab.defaultVisible)
        }

        // Which groups feed the menu-bar count; default to Review Requested.
        // (Set before the guard below, which reads computed props needing full init.)
        if let savedBadge = defaults.array(forKey: Key.badgeTabs) as? [String] {
            self.badgeTabs = Set(savedBadge.compactMap(PRTab.init(rawValue:))).intersection(knownTabs)
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

    /// The saved custom-tab definitions, or none — a fresh install, or JSON from
    /// a future build we can't read (drop rather than crash; the tabs reappear
    /// when that build runs again).
    private static func loadCustomTabs(_ defaults: UserDefaults) -> [CustomTab] {
        guard let data = defaults.data(forKey: Key.customTabs) else { return [] }
        return (try? JSONDecoder().decode([CustomTab].self, from: data)) ?? []
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
            guard secrets.set(token, for: .githubToken) else {
                return .failed(message: "Couldn't save your token to the Keychain. Check macOS Keychain access and try again.")
            }
            tokenRejected = false
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
        tokenRejected = false   // a deliberate disconnect isn't a rejection
        pullRequests = []
        signatureByID = [:]
        verdicts = [:]
        currentUserAvatarURL = nil
        loadError = nil
        startAutoRefresh()   // cancels the scheduler (no-op while disconnected)
    }

    // MARK: BYO API key (non-displayed; lives in Keychain)

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

    /// Switch provider, clearing the single saved key + model (there's exactly one
    /// connection). The endpoint resets to the new provider's preset — blank for
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
    ///     aiMode, byoProvider/Endpoint/Model, refreshInterval, panelBackground, cardDensity,
    ///     tabOrder/hiddenTabs/badgeTabs/customTabs, checkForUpdates (@AppStorage).
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
        panelBackground = .solid
        cardDensity = .detailed
        customTabs = []
        tabOrder = PRTab.builtin
        hiddenTabs = Set(PRTab.builtin).subtracting(PRTab.defaultVisible)
        badgeTabs = [.reviewRequested]
        selectedTab = .reviewRequested
        readSignatures = [:]

        // 2. Keychain — every slot we own.
        for key in SecretKey.allCases { secrets.set(nil, for: key) }

        // 3. Cache files (verdicts + read state). The `readStateInitialized` flag is
        //    swept with the rest of UserDefaults below, so the next sync re-seeds.
        verdictCache.clear()
        readStore.clear()

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
        if case .all = tab { return pullRequests }
        return pullRequests.filter { tab.matches($0) }
    }

    var tabCounts: [PRTab: Int] {
        // count(where:) rather than pullRequests(for:).count — no filtered-array
        // copies for a value the panel recomputes on every render.
        Dictionary(uniqueKeysWithValues: tabOrder.map { tab in
            (tab, pullRequests.count(where: tab.matches))
        })
    }

    /// PRs in the groups the user picked for the count (`badgeTabs`, default Review
    /// Requested), deduped across groups and independent of which tabs the panel
    /// shows. The pool the unread count draws from.
    private var badgePullRequests: [PullRequest] {
        pullRequests.filter { pr in
            badgeTabs.contains { $0.matches(pr) }
        }
    }

    /// The unread PRs within the badge groups — what the menu-bar number counts, so
    /// it reads as "new things to look at" and empties when you're caught up.
    private var unreadBadgePullRequests: [PullRequest] {
        badgePullRequests.filter { isUnread($0) }
    }

    /// The number on the menu-bar icon: unread PRs in the selected groups. Drops to
    /// zero when everything's been seen (the burrow empties).
    var badgeCount: Int { unreadBadgePullRequests.count }

    func verdictState(for pr: PullRequest) -> VerdictState {
        verdicts[pr.id] ?? (aiEnabled ? .loading : .off)
    }

    // MARK: Read / unread

    /// Content signatures for the current list, memoized. `VerdictInput.signature`
    /// hashes the PR body (a regex pass + SHA-256) — far too heavy for the
    /// `isUnread` checks every card, tab dot, and the badge make per render.
    /// Cleared when a fetch replaces the list; `@ObservationIgnored` because it's
    /// derived state no view should ever re-render on.
    @ObservationIgnored private var signatureByID: [String: String] = [:]

    private func signature(of pr: PullRequest) -> String {
        if let cached = signatureByID[pr.id] { return cached }
        let signature = VerdictInput(pr).signature
        signatureByID[pr.id] = signature
        return signature
    }

    /// Unread when we have no record of this PR, or its content changed since the
    /// user last marked it read. Uses the same `VerdictInput.signature` as the
    /// verdict cache, so a PR re-surfaces as unread on exactly the changes that
    /// re-run the AI (new commit, CI flip, review, labels) — not on mere chatter.
    func isUnread(_ pr: PullRequest) -> Bool {
        readSignatures[pr.id] != signature(of: pr)
    }

    /// Whether a tab holds any unread PRs — drives its dot in the tab bar.
    func hasUnread(in tab: PRTab) -> Bool {
        pullRequests.contains { tab.matches($0) && isUnread($0) }
    }

    /// The tabs currently holding unread PRs.
    var tabsWithUnread: Set<PRTab> {
        Set(tabOrder.filter { hasUnread(in: $0) })
    }

    /// The unread PRs in a tab — the basis for "Open all unread".
    func unreadPullRequests(in tab: PRTab) -> [PullRequest] {
        pullRequests(for: tab).filter { isUnread($0) }
    }

    func markRead(_ pr: PullRequest) {
        let signature = signature(of: pr)
        guard readSignatures[pr.id] != signature else { return }   // already read in this state
        readSignatures[pr.id] = signature
        readStore.save(readSignatures)
    }

    func markUnread(_ pr: PullRequest) {
        guard readSignatures[pr.id] != nil else { return }
        readSignatures.removeValue(forKey: pr.id)
        readStore.save(readSignatures)
    }

    /// Mark every PR in a tab read — the header's "Mark all read", scoped to the
    /// current tab. One write for the whole batch.
    func markAllRead(in tab: PRTab) {
        var changed = false
        for pr in pullRequests(for: tab) {
            let signature = signature(of: pr)
            guard readSignatures[pr.id] != signature else { continue }
            readSignatures[pr.id] = signature
            changed = true
        }
        if changed { readStore.save(readSignatures) }
    }

    /// Reconcile read state after each sync. On the very first run, treat the whole
    /// existing list as already seen (so a new user doesn't open to a wall of
    /// unread); then drop records for PRs that are gone, so the map tracks only the
    /// live set and can't grow unbounded. Writes once, and only if something changed.
    private func reconcileReadState() {
        var changed = false

        if !UserDefaults.standard.bool(forKey: Key.readStateInitialized) {
            for pr in pullRequests { readSignatures[pr.id] = signature(of: pr) }
            UserDefaults.standard.set(true, forKey: Key.readStateInitialized)
            changed = true
        }

        let live = Set(pullRequests.map(\.id))
        let before = readSignatures.count
        readSignatures = readSignatures.filter { live.contains($0.key) }
        if readSignatures.count != before { changed = true }

        if changed { readStore.save(readSignatures) }
    }

    /// Whether verdicts should compute at all. Mirrors `activeEngine != nil` but
    /// builds no engine and probes no framework, so it's safe to call while views
    /// render — `activeEngine` constructs an engine and must stay off that path.
    private var aiEnabled: Bool {
        switch aiMode {
        case .off:          return false
        case .onDevice:     return injectedEngine != nil || onDeviceAvailability.isAvailable
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
            return OnDeviceModel.makeEngine()
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
    /// The prompt/output-contract version, baked into every cache key (`engineTag`).
    /// Bump on any material change to the prompt or output so verdicts cached under an
    /// older prompt are re-run rather than served stale — and `VerdictCache.prune`
    /// then sweeps the superseded-version entries. (v5: tighter review line, no em dashes.)
    static let promptVersion = "v5"

    private var engineTag: String {
        switch aiMode {
        case .off:          return "off"
        case .onDevice:     return "ondevice@\(Self.promptVersion)"
        case .bringYourOwn: return "byo:\(byoProvider.rawValue):\(byoModel)@\(Self.promptVersion)"
        }
    }

    /// Why on-device AI can't run, for the Settings note — nil when it's available
    /// (or a preview/test engine is injected). Cards fall back to data-only meanwhile.
    var onDeviceUnavailableReason: String? {
        guard aiMode == .onDevice, injectedEngine == nil else { return nil }
        return onDeviceAvailability.reason
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

    /// The panel just opened. Warm the on-device model (so the first verdict is
    /// snappy, not cold) while the refresh fetches in parallel, then let
    /// `recomputeVerdicts` run the model now that someone's watching.
    func panelOpened() {
        onDeviceAvailability = OnDeviceModel.availability
        isPanelOpen = true
        activeEngine?.prewarm()              // no-op for remote/off; loads assets for on-device
        Task { await loadIfStale() }
    }

    /// The panel closed. Stop feeding the model: any in-flight verdict finishes and
    /// caches, but `recomputeVerdicts` schedules nothing new behind a closed panel.
    func panelClosed() {
        isPanelOpen = false
    }

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

    /// Set when `load()` is asked to fetch while a fetch is already running (e.g.
    /// a custom tab saved mid-refresh). The in-flight load runs one follow-up when
    /// it finishes, so the request coalesces instead of being dropped — a
    /// just-saved tab would otherwise sit falsely empty until the next refresh.
    private var reloadQueued = false

    func load() async {
        guard !isLoading else { reloadQueued = true; return }   // one fetch at a time; run again after
        guard isGitHubConnected else { return }                 // RootView shows the connect state
        isLoading = true
        loadError = nil
        do {
            let result = try await prProvider.fetchPullRequests(customTabs: customTabs)
            if let viewer = result.viewer { currentUser = viewer }
            if let avatar = result.viewerAvatarURL { currentUserAvatarURL = avatar }
            pullRequests = result.pullRequests
            signatureByID = [:]   // fresh content → signatures recompute lazily
            lastSyncedAt = .now
            reconcileReadState()
            isLoading = false
            await recomputeVerdicts()
        } catch {
            // A 401 means the token expired or was revoked mid-session. Drop the dead
            // token and route back to the connect screen (with context) instead of
            // stranding the user on a "Try again" that can only fail again.
            if let gh = error as? GitHubError, case .badToken = gh {
                secrets.set(nil, for: .githubToken)
                isGitHubConnected = false
                tokenRejected = true
                startAutoRefresh()   // cancels the now-pointless scheduler
            } else {
                loadError = error.localizedDescription
            }
            isLoading = false
        }

        // A fetch was requested while this one ran — run it now that we're free.
        if reloadQueued {
            reloadQueued = false
            await load()
        }
    }

    // MARK: Verdicts

    private func recomputeVerdicts() async {
        onDeviceAvailability = OnDeviceModel.availability   // refresh before we resolve
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
        // Run the model only while the panel is open. A background fetch updates the
        // list and badge, but the on-device model never spins up behind a closed
        // panel — stale PRs stay `.loading` and analyze the moment the panel opens.
        if isPanelOpen && !stale.isEmpty {
            // Concurrency the engine asks for: 1 on-device (the Neural Engine
            // serializes anyway, and a trickle keeps the Mac cool), more for remote.
            // Cards fill in as each verdict lands.
            await withTaskGroup(of: (PullRequest, VerdictState).self) { group in
                var next = 0
                func schedule() {
                    guard next < stale.count else { return }
                    let pr = stale[next]
                    next += 1
                    group.addTask { (pr, await Self.verdict(for: pr, using: engine)) }
                }
                for _ in 0..<min(engine.maxConcurrency, stale.count) { schedule() }
                for await (pr, state) in group {
                    // A newer recompute superseded us (mode/config changed): drain the
                    // in-flight tasks without writing, and schedule no more.
                    guard generation == recomputeGeneration else { continue }
                    verdicts[pr.id] = state
                    if case .ready(let verdict) = state {
                        verdictCache.store(verdict, for: pr, engine: tag)
                        stored = true
                    }
                    // Feed the model only while the panel stays open. If it closed
                    // mid-pass, in-flight verdicts still finish and cache, but nothing
                    // new starts — a closed panel never burns analyses you're not watching.
                    if isPanelOpen { schedule() }
                }
            }
            guard generation == recomputeGeneration else { return }
        }

        // Forget PRs that are gone (closed/merged), then save — but only when the
        // cache actually changed, so a fully-cached reopen does no disk write.
        let pruned = verdictCache.prune(toCurrent: pullRequests, version: Self.promptVersion)
        if stored || pruned { verdictCache.persist() }
    }

    /// One verdict, retried a couple times with brief backoff. Cold-start and
    /// transient model/network hiccups are the usual miss here; a retry clears them,
    /// so a single failure doesn't strand a card on `.failed` until its content
    /// changes. `nonisolated` so it runs off the main actor, like the task group wants.
    private nonisolated static func verdict(
        for pr: PullRequest, using engine: VerdictEngine, retries: Int = 2
    ) async -> VerdictState {
        for attempt in 0...retries {
            if Task.isCancelled { break }
            do { return .ready(try await withTimeout(seconds: 60) { try await engine.verdict(for: pr) }) }
            catch {
                // Back off a touch before retrying (400ms, then 800ms) so we're not
                // hammering a model that's still warming or an endpoint that's busy.
                if attempt < retries { try? await Task.sleep(for: .milliseconds(400 << attempt)) }
            }
        }
        return .failed("Couldn't analyze this PR.")
    }

    /// Runs `work`, failing if it doesn't finish within `seconds` — so one stuck
    /// inference or a hung endpoint can't strand a card (and, on-device where analysis
    /// runs one at a time, block every card queued behind it). The loser is cancelled.
    private nonisolated static func withTimeout<T: Sendable>(
        seconds: Double, _ work: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await work() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw TimeoutError()
            }
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }

    private struct TimeoutError: Error {}

    private func priority(of pr: PullRequest) -> Priority {
        if case .ready(let verdict) = verdictState(for: pr) { return verdict.priority }
        return .normal
    }
}
