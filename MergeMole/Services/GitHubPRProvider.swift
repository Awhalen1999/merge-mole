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

    func fetchPullRequests(customTabs: [CustomTab]) async throws -> PRFetchResult {
        guard let token = secrets.string(for: .githubToken), !token.isEmpty else {
            throw GitHubError.notConnected
        }
        return try await GitHubAPI.pullRequests(token: token, customTabs: customTabs)
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
    /// searches (one per relationship) run in the single query, joined by one more
    /// per custom tab; a PR that shows up in several buckets is merged once,
    /// accumulating every relationship and custom-tab membership.
    static func pullRequests(token: String, customTabs: [CustomTab] = []) async throws -> PRFetchResult {
        // Custom queries travel as GraphQL variables, never spliced into the query
        // string — user input can't break (or become) syntax.
        let variables = Dictionary(uniqueKeysWithValues: customTabs.enumerated().map {
            ("q\($0.offset)", wireQuery($0.element.query))
        })
        let data = try await send(query: prQuery(customCount: customTabs.count),
                                  variables: variables,
                                  token: token)
        let payload = try decode(PRPayload.self, from: data)

        var byID: [String: PullRequest] = [:]
        /// Fetch-or-create the PR for this node, then let the caller tag why it's
        /// here (a relationship, a custom-tab id). One PR accumulates every tag.
        func upsert(_ node: PRNode, tag: (inout PullRequest) -> Void) {
            guard let id = node.id else { return }
            if byID[id] == nil {
                guard let pr = pullRequest(from: node) else { return }
                byID[id] = pr
            }
            tag(&byID[id]!)
        }
        func merge(_ search: PRPayload.Search?, _ relationship: PRRelationship) {
            for node in search?.nodes ?? [] {
                // GitHub's `reviewed-by:@me` also returns your *own* PRs (you show up
                // in their review threads). Those belong under "Created", not
                // "Reviewed" — so drop the reviewed tag for anything you authored.
                if relationship == .reviewed, node.viewerDidAuthor == true { continue }
                upsert(node) { $0.relationships.insert(relationship) }
            }
        }
        merge(payload.searches["reviewRequested"], .reviewRequested)
        merge(payload.searches["assigned"],        .assigned)
        merge(payload.searches["created"],         .created)
        merge(payload.searches["mentioned"],       .mentioned)
        merge(payload.searches["reviewed"],        .reviewed)
        for (index, tab) in customTabs.enumerated() {
            for node in payload.searches["custom\(index)"]?.nodes ?? [] {
                upsert(node) { $0.customTabIDs.insert(tab.id) }
            }
        }

        return PRFetchResult(
            viewer: payload.viewer.login,
            viewerAvatarURL: payload.viewer.avatarUrl.flatMap(URL.init(string:)),
            pullRequests: Array(byID.values)
        )
    }

    /// The search actually sent for a custom tab. Always scoped to pull requests —
    /// the whole app is PRs, and without `is:pr` issues would eat the result budget
    /// and then silently vanish (the PR fragment skips them). Adds the dashboard's
    /// freshness sort unless the user chose their own.
    private static func wireQuery(_ raw: String) -> String {
        var query = "is:pr \(raw)"
        if !raw.localizedCaseInsensitiveContains("sort:") { query += " sort:updated-desc" }
        return query
    }

    /// Verifies a token and returns the login it belongs to. Used to validate
    /// before storing, so an invalid token never gets saved.
    static func viewerLogin(token: String) async throws -> String {
        let data = try await send(query: "query { viewer { login } }", token: token)
        return try decode(ViewerPayload.self, from: data).viewer.login
    }

    // MARK: Transport

    private static func send(query: String, variables: [String: String] = [:], token: String) async throws -> Data {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("MergeMole", forHTTPHeaderField: "User-Agent")
        var body: [String: Any] = ["query": query]
        if !variables.isEmpty { body["variables"] = variables }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

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

    private static func pullRequest(from node: PRNode) -> PullRequest? {
        // Search can return empty nodes (e.g. issues a custom query matched, which
        // the PR fragment skips); drop anything missing the essentials. The caller
        // tags relationships / custom-tab membership after creation.
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
            relationships: []
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

    /// One query: five aliased searches — each the same qualifier GitHub's own
    /// "Pull requests" dashboard uses for that bucket — plus one per custom tab,
    /// bound to a `$q<n>` variable. `reviewed-by` and `mentions` can't be derived
    /// from a PR's own fields, which is why we ask the search API per relationship
    /// rather than filtering one `involves:@me` list client-side.
    private static func prQuery(customCount: Int) -> String {
        let params = (0..<customCount).map { "$q\($0): String!" }.joined(separator: ", ")
        let customSearches = (0..<customCount).map {
            "  custom\($0): search(query: $q\($0), type: ISSUE, first: 40) { nodes { ...PRFields } }\n"
        }.joined()
        return """
    query\(customCount == 0 ? "" : "(\(params))") {
      viewer { login avatarUrl(size: 128) }
      reviewRequested: search(query: "is:open is:pr review-requested:@me sort:updated-desc", type: ISSUE, first: 40) { nodes { ...PRFields } }
      assigned:        search(query: "is:open is:pr assignee:@me sort:updated-desc", type: ISSUE, first: 40) { nodes { ...PRFields } }
      created:         search(query: "is:open is:pr author:@me sort:updated-desc", type: ISSUE, first: 40) { nodes { ...PRFields } }
      mentioned:       search(query: "is:open is:pr mentions:@me sort:updated-desc", type: ISSUE, first: 40) { nodes { ...PRFields } }
      reviewed:        search(query: "is:open is:pr reviewed-by:@me sort:updated-desc", type: ISSUE, first: 40) { nodes { ...PRFields } }
    \(customSearches)}

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
    /// Every search in the query, keyed by its alias — the five fixed relationship
    /// buckets plus one `custom<n>` per saved tab. Aliases are dynamic, so they
    /// decode as a dictionary rather than fixed properties. A search GitHub
    /// rejected comes back null and simply isn't here; its tab shows empty
    /// rather than erroring.
    let searches: [String: Search]

    struct Search: Decodable { let nodes: [PRNode] }

    private struct Key: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(_ name: String) { stringValue = name }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        viewer = try container.decode(Viewer.self, forKey: Key("viewer"))
        var searches: [String: Search] = [:]
        for key in container.allKeys where key.stringValue != "viewer" {
            searches[key.stringValue] = try container.decodeIfPresent(Search.self, forKey: key)
        }
        self.searches = searches
    }
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
