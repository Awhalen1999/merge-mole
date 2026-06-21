import Foundation

/// Errors surfaced to the user when talking to GitHub. `LocalizedError`, so
/// `error.localizedDescription` is always a clean, user-facing sentence.
enum GitHubError: LocalizedError {
    case notConnected
    case badToken
    case http(Int, String?)
    case graphQL(String)
    case network

    var errorDescription: String? {
        switch self {
        case .notConnected: return "Not connected to GitHub."
        case .badToken:     return "That token was rejected by GitHub. Double-check it and try again."
        case .http(let code, let message):
            if let message, !message.isEmpty { return "GitHub error (HTTP \(code)): \(message)" }
            return "GitHub returned an error (HTTP \(code))."
        case .graphQL(let message): return message
        case .network:      return "Couldn't reach GitHub. Check your connection."
        }
    }
}

/// Normalizes a pasted token. A real token contains no whitespace, so stripping
/// it removes stray spaces/newlines that would otherwise produce a malformed
/// `Authorization` header (and a confusing "unauthenticated" failure).
enum GitHubToken {
    static func sanitize(_ raw: String) -> String {
        raw.filter { !$0.isWhitespace }
    }
}

/// The PR source backed by GitHub. Thin by design: it reads the token fresh from
/// the Keychain each call (so connect/disconnect just works) and hands off to
/// `GitHubAPI`, which owns all the networking and decoding.
struct GitHubPRProvider: PRProvider {
    let secrets: SecretStore

    func fetchPullRequests() async throws -> PRFetchResult {
        guard let token = secrets.string(for: .githubToken), !token.isEmpty else {
            throw GitHubError.notConnected
        }
        return try await GitHubAPI.pullRequests(token: token)
    }
}

/// All GitHub GraphQL networking lives here, behind two intent-revealing calls.
/// Both flow through `send`, so auth, status codes, and GraphQL-level errors are
/// handled in exactly one place.
enum GitHubAPI {
    private static let endpoint = URL(string: "https://api.github.com/graphql")!

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// The PRs that involve you, plus your login — one round-trip.
    static func pullRequests(token: String) async throws -> PRFetchResult {
        let data = try await send(query: prQuery, token: token)
        let payload = try decode(PRPayload.self, from: data)
        let prs = payload.search.nodes.compactMap(pullRequest(from:))
        return PRFetchResult(viewer: payload.viewer.login, pullRequests: prs)
    }

    /// Verifies a token and returns the login it belongs to. Used to validate
    /// before storing, so an invalid token never gets saved.
    static func viewerLogin(token: String) async throws -> String {
        let data = try await send(query: "query { viewer { login } }", token: token)
        return try decode(ViewerPayload.self, from: data).viewer.login
    }

    // MARK: Transport

    private static func send(query: String, token: String) async throws -> Data {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("MergeMole", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["query": query])

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
        default:  throw GitHubError.http(http.statusCode, restMessage(from: data))
        }

        // GraphQL-level errors come back with HTTP 200 and an `errors` array.
        if let message = (try? decoder.decode(GraphQLErrors.self, from: data))?.errors?.first?.message {
            throw GitHubError.graphQL(message)
        }
        return data
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        guard let payload = try decoder.decode(Envelope<T>.self, from: data).data else {
            throw GitHubError.graphQL("GitHub returned no data.")
        }
        return payload
    }

    /// REST-style error bodies are `{"message": "...", "documentation_url": "..."}`.
    private static func restMessage(from data: Data) -> String? {
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        return object?["message"] as? String
    }

    // MARK: Mapping

    private static func pullRequest(from node: PRNode) -> PullRequest? {
        // Search can return empty nodes; skip anything missing the essentials.
        guard let id = node.id,
              let number = node.number,
              let title = node.title,
              let repository = node.repository?.nameWithOwner,
              let urlString = node.url,
              let url = URL(string: urlString)
        else { return nil }

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
            checksState: checksState(node.commits?.nodes.first?.commit.statusCheckRollup?.state),
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
        case "SUCCESS":             return .passing
        case "FAILURE", "ERROR":    return .failing
        case "PENDING", "EXPECTED": return .pending
        default:                    return .unknown
        }
    }

    private static let prQuery = """
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
}

// MARK: - GraphQL response shapes

private struct Envelope<T: Decodable>: Decodable { let data: T? }

private struct GraphQLErrors: Decodable {
    let errors: [Item]?
    struct Item: Decodable { let message: String }
}

private struct Viewer: Decodable { let login: String }

private struct ViewerPayload: Decodable { let viewer: Viewer }

private struct PRPayload: Decodable {
    let viewer: Viewer
    let search: Search
    struct Search: Decodable { let nodes: [PRNode] }
}

private struct PRNode: Decodable {
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

    struct Repository: Decodable { let nameWithOwner: String }
    struct Author: Decodable { let login: String }
    struct Commits: Decodable {
        let nodes: [CommitNode]
        struct CommitNode: Decodable { let commit: Commit }
        struct Commit: Decodable { let statusCheckRollup: Rollup? }
        struct Rollup: Decodable { let state: String }
    }
}
