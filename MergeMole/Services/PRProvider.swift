import Foundation

/// The result of a fetch: the PRs plus who the signed-in user is, so AppModel can
/// resolve `currentUser` (drives the Mine / Needs Review filters) from the same
/// round-trip.
struct PRFetchResult: Sendable {
    var viewer: String?
    var viewerAvatarURL: URL? = nil
    var pullRequests: [PullRequest]
}

/// Source of pull requests. The whole app talks to this protocol, never to a
/// concrete backend — so the sample provider and `GitHubPRProvider` are
/// interchangeable and AppModel/the views don't care which is wired in.
protocol PRProvider: Sendable {
    func fetchPullRequests() async throws -> PRFetchResult
}

/// Returns the fixed fake set. Used by previews/tests; production uses GitHub.
struct SamplePRProvider: PRProvider {
    /// Simulated network latency so the loading state is visible during dev.
    var latency: Duration = .milliseconds(300)

    func fetchPullRequests() async throws -> PRFetchResult {
        try await Task.sleep(for: latency)
        return PRFetchResult(viewer: SampleData.currentUser, pullRequests: SampleData.pullRequests)
    }
}
