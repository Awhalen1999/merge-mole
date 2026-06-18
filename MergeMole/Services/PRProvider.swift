import Foundation

/// Source of pull requests. The whole app talks to this protocol, never to a
/// concrete backend — so Step 3 swaps `SamplePRProvider` for a GraphQL-backed
/// `GitHubPRProvider` without touching AppModel or the views.
protocol PRProvider: Sendable {
    func fetchPullRequests() async throws -> [PullRequest]
}

/// Returns the fixed fake set. Stand-in until real GitHub fetching lands.
struct SamplePRProvider: PRProvider {
    /// Simulated network latency so the loading state is visible during dev.
    var latency: Duration = .milliseconds(300)

    func fetchPullRequests() async throws -> [PullRequest] {
        try await Task.sleep(for: latency)
        return SampleData.pullRequests
    }
}
