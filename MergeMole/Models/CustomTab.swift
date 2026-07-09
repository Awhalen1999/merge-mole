import Foundation

/// A user-defined panel tab backed by a raw GitHub search — anything a search can
/// express (a repo, a label, a team's review queue) can be a tab. The rest of the
/// app references it by id (`PRTab.custom`), so renaming or editing the query never
/// disturbs tab order, visibility, badge membership, or the selection.
///
/// Definitions persist as JSON in UserDefaults alongside the other preferences
/// (see `AppModel.customTabs`); matching PRs are fetched by `GitHubPRProvider` in
/// the same round-trip as the built-in tabs.
struct CustomTab: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    /// The GitHub search exactly as the user wrote it, e.g.
    /// `is:open review-requested:@me label:api`. The provider scopes it to pull
    /// requests on the wire (`is:pr`) — see `GitHubAPI.wireQuery`.
    var query: String

    init(id: UUID = UUID(), name: String, query: String) {
        self.id = id
        self.name = name
        self.query = query
    }
}
