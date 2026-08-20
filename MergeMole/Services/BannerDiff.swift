import Foundation

/// The notification decision, whole and pure: which banners ring and which get
/// swept after a sync. `AppModel.load()` feeds it a before/after picture of the
/// unread badge pool and applies the outcome; every rule lives here and nowhere
/// else, so the rules are testable without a model and extendable in one file.
///
/// The rules, in the order they apply:
///   • Sweep first: a banner never outlives its reason. Any PR that was unread
///     before the sync and isn't now (read elsewhere and absorbed, or gone from
///     the list) has its banner removed.
///   • A session's first sync is a silent baseline — everything that changed
///     while the app wasn't running lights the badge, never Notification
///     Center. `reset()` re-arms this for a reconnect.
///   • No banners while the panel is open: the user is already looking, and
///     the PR stays unread so it isn't an edge at the next sync either.
///   • Only edges ring: a PR unread before the sync is not news. One banner
///     per unread episode; further activity stays quiet until it's read.
///   • The mode narrows which edges ring: `.newPRs` only for PRs with no read
///     record (the "new" flavor of unread), `.follow` for any edge.
struct BannerDiff {

    /// One currently-unread PR in the badge pool, as the decision sees it.
    /// `isNew` is "no read record": the first branch of `isUnread`.
    struct Candidate {
        let id: String
        let isNew: Bool
    }

    /// What a sync decided: banners to remove, PRs to ring for.
    struct Outcome {
        let sweptIDs: [String]
        let ringIDs: Set<String>
    }

    /// False until the first sync has been scored. The diff needs a real
    /// "before" to compare against; without one, everything looks like an edge.
    private var hasBaseline = false

    mutating func afterSync(
        before: Set<String>,
        now: [Candidate],
        mode: NotifyMode,
        panelOpen: Bool
    ) -> Outcome {
        let nowIDs = Set(now.map(\.id))
        let swept = Array(before.subtracting(nowIDs))
        defer { hasBaseline = true }   // even a silenced sync is a valid "before"

        guard mode != .off, hasBaseline, !panelOpen else {
            return Outcome(sweptIDs: swept, ringIDs: [])
        }
        let rings = now.filter { !before.contains($0.id) && (mode != .newPRs || $0.isNew) }
        return Outcome(sweptIDs: swept, ringIDs: Set(rings.map(\.id)))
    }

    /// Forget the baseline — on disconnect, so a reconnect's first sync is a
    /// baseline again instead of a wall of banners.
    mutating func reset() {
        hasBaseline = false
    }
}
