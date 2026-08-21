import Foundation

/// The notification decision, whole and pure: which banners ring and which get
/// swept after a sync. `AppModel.load()` feeds it a before/after picture of the
/// unread badge pool and applies the outcome; every rule lives here and nowhere
/// else, so the rules are testable without a model and extendable in one file.
///
/// Notifications deliberately have no filter of their own. They fire exactly
/// when the unread dot would appear on a watched PR, so the user's Flag mode
/// and signal choices tune both at once — in New-PRs-only mode, activity never
/// turns a read PR unread, so the only edges that can exist are new PRs. That
/// sync is structural: nothing here implements it, nothing can break it.
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
struct BannerDiff {

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
        now: Set<String>,
        enabled: Bool,
        panelOpen: Bool
    ) -> Outcome {
        let swept = Array(before.subtracting(now))
        defer { hasBaseline = true }   // even a silenced sync is a valid "before"

        guard enabled, hasBaseline, !panelOpen else {
            return Outcome(sweptIDs: swept, ringIDs: [])
        }
        return Outcome(sweptIDs: swept, ringIDs: now.subtracting(before))
    }

    /// Forget the baseline — on disconnect, so a reconnect's first sync is a
    /// baseline again instead of a wall of banners.
    mutating func reset() {
        hasBaseline = false
    }
}
