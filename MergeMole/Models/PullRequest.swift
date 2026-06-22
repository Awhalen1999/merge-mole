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
    var body: String        // PR description (plain text; may be empty)
    var repository: String  // "owner/name"
    var author: String
    var headBranch: String
    var baseBranch: String
    var headOID: String     // head commit SHA — the source of truth for "content changed"
    var isDraft: Bool
    var reviewState: ReviewState
    var checksState: ChecksState
    var mergeable: MergeState   // can it merge cleanly, or does it conflict with base?
    var additions: Int
    var deletions: Int
    var changedFiles: Int
    var commentCount: Int   // total comments incl. review comments — how much discussion
    var resolvedThreads: Int    // review conversations marked resolved
    var unresolvedThreads: Int  // review conversations still open — the actionable count
    var labels: [String]    // e.g. "security", "bug" — high-signal for priority
    var url: URL
    var createdAt: Date     // when the PR was opened — lets us read true age, not just "updated"
    var updatedAt: Date

    /// Which "involves you" buckets GitHub returned this PR in (review requested,
    /// assigned, …). A PR can be in several at once, so it's a set; it drives which
    /// panel tab(s) the PR shows under. Viewer-relative — set by the provider, not
    /// an intrinsic fact about the PR.
    var relationships: Set<PRRelationship>

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

    /// Whether the PR can merge into its base. GitHub computes this asynchronously,
    /// so `unknown` is common right after a push — only `conflicting` is worth a badge.
    enum MergeState: String, Sendable {
        case unknown
        case clean          // GitHub `MERGEABLE`
        case conflicting    // GitHub `CONFLICTING`
    }
}

/// Why a PR involves you — the search bucket GitHub returned it in. Tabs are a
/// thin presentation layer over these (one tab per relationship). Lives in the
/// model (not the UI) because the provider is what decides membership.
enum PRRelationship: String, CaseIterable, Sendable, Hashable {
    case reviewRequested    // your review is requested
    case assigned           // assigned to you
    case created            // you opened it
    case mentioned          // you're @-mentioned
    case reviewed           // you've already reviewed it
}
