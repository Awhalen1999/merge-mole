import Foundation

/// A pull request as MergeMole understands it — provider-agnostic.
///
/// `SamplePRProvider` fills this from fake data today; `GitHubPRProvider` will
/// fill the *same* shape from the GraphQL API at Step 3, so nothing downstream
/// (views, AppModel, the AI engine) has to change when real data arrives.
struct PullRequest: Identifiable, Hashable, Sendable {
    let id: String          // GraphQL node id later; a stable string for samples
    var number: Int
    var title: String
    var repository: String  // "owner/name"
    var author: String
    var headBranch: String
    var baseBranch: String
    var isDraft: Bool
    var reviewState: ReviewState
    var checksState: ChecksState
    var additions: Int
    var deletions: Int
    var changedFiles: Int
    var url: URL
    var updatedAt: Date

    var changedLines: Int { additions + deletions }

    /// Native, AI-free size classification (see `SizeBucket`).
    var sizeBucket: SizeBucket { SizeBucket(changedLines: changedLines) }
}

extension PullRequest {
    /// The aggregate review decision GitHub reports for the PR.
    enum ReviewState: String, Sendable {
        case pending             // awaiting review
        case changesRequested
        case approved
    }

    /// Rolled-up CI / status-check result for the head commit.
    enum ChecksState: String, Sendable {
        case unknown
        case pending
        case passing
        case failing
    }
}
