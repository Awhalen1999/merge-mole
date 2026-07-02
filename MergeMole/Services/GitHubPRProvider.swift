import Foundation
import os

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

    /// In DEBUG, the raw GraphQL response is logged here so the exact API shape is
    /// inspectable. View it with:
    ///   log stream --predicate 'subsystem == "app.mergemole.MergeMole"' --debug
    /// or after the fact: log show --last 5m --predicate 'subsystem == "app.mergemole.MergeMole"' --debug
    private static let log = Logger(subsystem: "app.mergemole.MergeMole", category: "GitHubAPI")

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// A short-timeout session so a stalled connection (captive-portal wifi, a VPN
    /// dropping) fails fast instead of leaving the panel spinning. `waitsForConnectivity
    /// = false` means "offline" errors out immediately rather than queueing the request.
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    /// The PRs that involve you, plus your login — one round-trip. Five aliased
    /// searches (one per relationship) run in the single query; a PR that shows up
    /// in more than one bucket is merged once, accumulating every relationship.
    static func pullRequests(token: String) async throws -> PRFetchResult {
        let data = try await send(query: prQuery, token: token)
        let payload = try decode(PRPayload.self, from: data)

        var byID: [String: PullRequest] = [:]
        func merge(_ search: PRPayload.Search?, _ relationship: PRRelationship) {
            for node in search?.nodes ?? [] {
                // GitHub's `reviewed-by:@me` also returns your *own* PRs (you show up
                // in their review threads). Those belong under "Created", not
                // "Reviewed" — so drop the reviewed tag for anything you authored.
                if relationship == .reviewed, node.viewerDidAuthor == true { continue }
                guard let pr = pullRequest(from: node, relationship: relationship) else { continue }
                if byID[pr.id] != nil {
                    byID[pr.id]?.relationships.insert(relationship)
                } else {
                    byID[pr.id] = pr
                }
            }
        }
        merge(payload.reviewRequested, .reviewRequested)
        merge(payload.assigned,        .assigned)
        merge(payload.created,         .created)
        merge(payload.mentioned,       .mentioned)
        merge(payload.reviewed,        .reviewed)

        return PRFetchResult(
            viewer: payload.viewer.login,
            viewerAvatarURL: payload.viewer.avatarUrl.flatMap(URL.init(string:)),
            pullRequests: Array(byID.values)
        )
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
            (data, response) = try await session.data(for: request)
        } catch {
            throw GitHubError.network
        }

        guard let http = response as? HTTPURLResponse else { throw GitHubError.network }
        switch http.statusCode {
        case 200: break
        case 401: throw GitHubError.badToken
        default:  throw GitHubError.http(http.statusCode, restMessage(from: data))
        }

        #if DEBUG
        // Pretty-print so the response shape is easy to read in Console; falls back
        // to the raw bytes if it isn't valid JSON.
        let pretty = (try? JSONSerialization.jsonObject(with: data))
            .flatMap { try? JSONSerialization.data(withJSONObject: $0, options: [.prettyPrinted, .sortedKeys]) }
            .flatMap { String(data: $0, encoding: .utf8) }
        log.debug("GitHub GraphQL response:\n\(pretty ?? String(decoding: data, as: UTF8.self), privacy: .public)")
        #endif

        // GraphQL errors come back as HTTP 200 with an `errors` array — but often
        // alongside partial `data` (e.g. one of the five aliased searches failed while
        // the rest succeeded). Keep the partial results; only surface the error when
        // there's no usable data at all, so one flaky bucket can't wipe the whole list.
        let hasData = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["data"] is [String: Any]
        if !hasData, let message = (try? decoder.decode(GraphQLErrors.self, from: data))?.errors?.first?.message {
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

    private static func pullRequest(from node: PRNode, relationship: PRRelationship) -> PullRequest? {
        // Search can return empty nodes; skip anything missing the essentials.
        guard let id = node.id,
              let number = node.number,
              let title = node.title,
              let repository = node.repository?.nameWithOwner,
              let urlString = node.url,
              let url = URL(string: urlString)
        else { return nil }

        var pr = PullRequest(
            id: id,
            number: number,
            title: title,
            body: node.bodyText ?? "",
            repository: repository,
            author: node.author?.login ?? "unknown",
            authorAvatarURL: node.author?.avatarUrl.flatMap(URL.init(string:)),
            headBranch: node.headRefName ?? "",
            baseBranch: node.baseRefName ?? "",
            headOID: node.headRefOid ?? "",
            isDraft: node.isDraft ?? false,
            reviewState: reviewState(node.reviewDecision),
            checksState: checksState(node.commits?.nodes.first?.commit.statusCheckRollup?.state),
            mergeable: mergeState(node.mergeable),
            additions: node.additions ?? 0,
            deletions: node.deletions ?? 0,
            changedFiles: node.changedFiles ?? 0,
            commentCount: node.totalCommentsCount ?? 0,   // includes review comments, not just the conversation
            resolvedThreads: (node.reviewThreads?.nodes ?? []).filter { $0.isResolved == true }.count,
            unresolvedThreads: (node.reviewThreads?.nodes ?? []).filter { $0.isResolved == false }.count,
            labels: node.labels?.nodes.compactMap(\.name) ?? [],
            url: url,
            createdAt: node.createdAt ?? .now,
            updatedAt: node.updatedAt ?? .now,
            relationships: [relationship]
        )

        // Extra triage signals (defaulted on the model, set here from the API).
        pr.commitCount = node.commits?.totalCount ?? 0
        pr.approvals = (node.latestOpinionatedReviews?.nodes ?? []).filter { $0.state == "APPROVED" }.count
        pr.isBehindBase = node.mergeStateStatus == "BEHIND"
        pr.isFirstTimeContributor = node.authorAssociation == "FIRST_TIME_CONTRIBUTOR"
            || node.authorAssociation == "FIRST_TIMER"
        pr.isFromFork = node.isCrossRepository ?? false
        pr.requestedReviewers = (node.reviewRequests?.nodes ?? []).compactMap { node in
            guard let login = node.requestedReviewer?.login else { return nil }   // users only; skip teams/bots
            return PRReviewer(login: login, avatarURL: node.requestedReviewer?.avatarUrl.flatMap(URL.init(string:)))
        }
        return pr
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

    private static func mergeState(_ state: String?) -> PullRequest.MergeState {
        switch state {
        case "MERGEABLE":   return .clean
        case "CONFLICTING": return .conflicting
        default:            return .unknown   // UNKNOWN — GitHub hasn't computed it yet
        }
    }

    /// One query, five aliased searches — each is the same qualifier GitHub's own
    /// "Pull requests" dashboard uses for that bucket. `reviewed-by` and `mentions`
    /// can't be derived from a PR's own fields, which is why we ask the search API
    /// per relationship rather than filtering one `involves:@me` list client-side.
    private static let prQuery = """
    query {
      viewer { login avatarUrl(size: 128) }
      reviewRequested: search(query: "is:open is:pr review-requested:@me sort:updated-desc", type: ISSUE, first: 40) { nodes { ...PRFields } }
      assigned:        search(query: "is:open is:pr assignee:@me sort:updated-desc", type: ISSUE, first: 40) { nodes { ...PRFields } }
      created:         search(query: "is:open is:pr author:@me sort:updated-desc", type: ISSUE, first: 40) { nodes { ...PRFields } }
      mentioned:       search(query: "is:open is:pr mentions:@me sort:updated-desc", type: ISSUE, first: 40) { nodes { ...PRFields } }
      reviewed:        search(query: "is:open is:pr reviewed-by:@me sort:updated-desc", type: ISSUE, first: 40) { nodes { ...PRFields } }
    }

    fragment PRFields on PullRequest {
      id
      number
      title
      bodyText
      isDraft
      url
      createdAt
      updatedAt
      additions
      deletions
      changedFiles
      mergeable
      mergeStateStatus
      authorAssociation
      isCrossRepository
      totalCommentsCount
      viewerDidAuthor
      reviewThreads(first: 100) { nodes { isResolved } }
      latestOpinionatedReviews(first: 20) { nodes { state } }
      reviewRequests(first: 10) {
        nodes { requestedReviewer { __typename ... on User { login avatarUrl(size: 64) } } }
      }
      repository { nameWithOwner }
      author { login avatarUrl(size: 64) }
      headRefName
      baseRefName
      headRefOid
      reviewDecision
      labels(first: 10) { nodes { name } }
      commits(last: 1) {
        totalCount
        nodes { commit { statusCheckRollup { state } } }
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

private struct Viewer: Decodable { let login: String; let avatarUrl: String? }

private struct ViewerPayload: Decodable { let viewer: Viewer }

private struct PRPayload: Decodable {
    let viewer: Viewer
    let reviewRequested: Search?
    let assigned: Search?
    let created: Search?
    let mentioned: Search?
    let reviewed: Search?
    struct Search: Decodable { let nodes: [PRNode] }
}

private struct PRNode: Decodable {
    let id: String?
    let number: Int?
    let title: String?
    let bodyText: String?
    let isDraft: Bool?
    let url: String?
    let createdAt: Date?
    let updatedAt: Date?
    let additions: Int?
    let deletions: Int?
    let changedFiles: Int?
    let mergeable: String?
    let mergeStateStatus: String?
    let authorAssociation: String?
    let isCrossRepository: Bool?
    let totalCommentsCount: Int?
    let viewerDidAuthor: Bool?
    let reviewThreads: ReviewThreads?
    let latestOpinionatedReviews: Reviews?
    let reviewRequests: ReviewRequests?
    let repository: Repository?
    let author: Author?
    let headRefName: String?
    let baseRefName: String?
    let headRefOid: String?
    let reviewDecision: String?
    let labels: Labels?
    let commits: Commits?

    struct Repository: Decodable { let nameWithOwner: String }
    struct ReviewThreads: Decodable {
        let nodes: [Thread]
        struct Thread: Decodable { let isResolved: Bool? }
    }
    struct Reviews: Decodable {
        let nodes: [Review]
        struct Review: Decodable { let state: String? }
    }
    struct ReviewRequests: Decodable {
        let nodes: [Node]
        struct Node: Decodable { let requestedReviewer: Reviewer? }
        struct Reviewer: Decodable { let login: String?; let avatarUrl: String? }
    }
    struct Author: Decodable { let login: String; let avatarUrl: String? }
    struct Labels: Decodable {
        let nodes: [LabelNode]
        struct LabelNode: Decodable { let name: String }
    }
    struct Commits: Decodable {
        let totalCount: Int?
        let nodes: [CommitNode]
        struct CommitNode: Decodable { let commit: Commit }
        struct Commit: Decodable { let statusCheckRollup: Rollup? }
        struct Rollup: Decodable { let state: String }
    }
}
