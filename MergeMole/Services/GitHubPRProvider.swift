import Foundation

/// Errors surfaced to the user when talking to GitHub.
enum GitHubError: LocalizedError {
    case notConnected
    case badToken
    case http(Int, String?)
    case graphQL(String)
    case network

    var errorDescription: String? {
        switch self {
        case .notConnected: return "Not connected to GitHub."
        case .badToken:     return "Your GitHub token was rejected. Add a new one in Settings."
        case .http(let code, let message):
            if let message, !message.isEmpty { return "GitHub error (HTTP \(code)): \(message)" }
            return "GitHub returned an error (HTTP \(code))."
        case .graphQL(let m): return m
        case .network:      return "Couldn't reach GitHub. Check your connection."
        }
    }
}

/// Fetches the PRs that involve you via one GitHub GraphQL query — review state,
/// CI rollup, and line counts in a single round-trip. Reads the token fresh from
/// the Keychain each call, so connecting/disconnecting just works.
struct GitHubPRProvider: PRProvider {
    let secrets: SecretStore

    private static let endpoint = URL(string: "https://api.github.com/graphql")!

    private static let query = """
    query {
      viewer { login }
      search(query: "is:open is:pr involves:@me sort:updated-desc", type: ISSUE, first: 50) {
        nodes {
          ... on PullRequest {
            id
            number
            title
            isDraft
            url
            updatedAt
            additions
            deletions
            changedFiles
            repository { nameWithOwner }
            author { login }
            headRefName
            baseRefName
            reviewDecision
            commits(last: 1) {
              nodes { commit { statusCheckRollup { state } } }
            }
          }
        }
      }
    }
    """

    func fetchPullRequests() async throws -> PRFetchResult {
        guard let token = secrets.string(for: .githubToken), !token.isEmpty else {
            throw GitHubError.notConnected
        }

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("MergeMole", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["query": Self.query])

        let data: Data, response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw GitHubError.network
        }

        guard let http = response as? HTTPURLResponse else { throw GitHubError.network }
        switch http.statusCode {
        case 200: break
        case 401: throw GitHubError.badToken
        default:  throw GitHubError.http(http.statusCode, Self.message(from: data))
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(GraphQLResponse.self, from: data)

        if let message = decoded.errors?.first?.message {
            throw GitHubError.graphQL(message)
        }
        guard let payload = decoded.data else {
            throw GitHubError.graphQL("GitHub returned no data.")
        }

        let prs = payload.search.nodes.compactMap(Self.pullRequest(from:))
        return PRFetchResult(viewer: payload.viewer.login, pullRequests: prs)
    }

    /// GitHub error bodies are `{"message": "...", "documentation_url": "..."}`.
    private static func message(from data: Data) -> String? {
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return object?["message"] as? String
    }

    // MARK: Mapping

    private static func pullRequest(from node: GraphQLResponse.Node) -> PullRequest? {
        // Search can return empty nodes; skip anything missing the essentials.
        guard let id = node.id,
              let number = node.number,
              let title = node.title,
              let repository = node.repository?.nameWithOwner,
              let urlString = node.url,
              let url = URL(string: urlString)
        else { return nil }

        let rollup = node.commits?.nodes.first?.commit.statusCheckRollup?.state
        return PullRequest(
            id: id,
            number: number,
            title: title,
            repository: repository,
            author: node.author?.login ?? "unknown",
            headBranch: node.headRefName ?? "",
            baseBranch: node.baseRefName ?? "",
            isDraft: node.isDraft ?? false,
            reviewState: reviewState(node.reviewDecision),
            checksState: checksState(rollup),
            additions: node.additions ?? 0,
            deletions: node.deletions ?? 0,
            changedFiles: node.changedFiles ?? 0,
            url: url,
            updatedAt: node.updatedAt ?? .now
        )
    }

    private static func reviewState(_ decision: String?) -> PullRequest.ReviewState {
        switch decision {
        case "APPROVED":          return .approved
        case "CHANGES_REQUESTED": return .changesRequested
        default:                  return .pending
        }
    }

    private static func checksState(_ state: String?) -> PullRequest.ChecksState {
        switch state {
        case "SUCCESS":            return .passing
        case "FAILURE", "ERROR":   return .failing
        case "PENDING", "EXPECTED": return .pending
        default:                   return .unknown
        }
    }
}

// MARK: - GraphQL response shape

private struct GraphQLResponse: Decodable {
    let data: Payload?
    let errors: [GQLError]?

    struct GQLError: Decodable { let message: String }

    struct Payload: Decodable {
        let viewer: Viewer
        let search: Search
    }
    struct Viewer: Decodable { let login: String }
    struct Search: Decodable { let nodes: [Node] }

    struct Node: Decodable {
        let id: String?
        let number: Int?
        let title: String?
        let isDraft: Bool?
        let url: String?
        let updatedAt: Date?
        let additions: Int?
        let deletions: Int?
        let changedFiles: Int?
        let repository: Repository?
        let author: Author?
        let headRefName: String?
        let baseRefName: String?
        let reviewDecision: String?
        let commits: Commits?
    }
    struct Repository: Decodable { let nameWithOwner: String }
    struct Author: Decodable { let login: String }
    struct Commits: Decodable {
        let nodes: [CommitNode]
        struct CommitNode: Decodable { let commit: Commit }
        struct Commit: Decodable { let statusCheckRollup: Rollup? }
        struct Rollup: Decodable { let state: String }
    }
}
