import Foundation

struct PullRequestStack: Identifiable, Hashable, Sendable {
    var id: String          // GraphQL ID (ID!) — a server-assigned string
    var number: Int
    var size: Int
    var baseRefName: String
    var entries: PullRequestStackEntryConnection
}

struct PullRequestStackEntry: Identifiable, Hashable, Sendable {
    var id: String          // GraphQL ID (ID!) — a server-assigned string
    var position: Int
//    var pullRequest: PullRequest
    var stack: PullRequestStack
}

struct PullRequestStackEntryConnection: Hashable, Sendable {
    var edges: [PullRequestStackEntryEdge]
    var nodes: [PullRequestStackEntry]
//    var pageInfo: PageInfo
    var totalCount: Int
}

struct PullRequestStackEntryEdge: Hashable, Sendable {
    var cursor: String
    var node: PullRequestStackEntry
}
