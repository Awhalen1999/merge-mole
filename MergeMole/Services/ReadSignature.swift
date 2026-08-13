import Foundation
import CryptoKit

/// What the unread dot means (Settings → Unread). `newOnly` flags a PR once, when
/// it first appears, and opening it clears it for good; `activity` re-flags on
/// the signals the user picked (`UnreadSignal`). Separate from `unreadSignals`
/// so switching modes never destroys the checkbox configuration.
enum UnreadMode: String, CaseIterable, Identifiable, Sendable {
    case newOnly, activity   // order drives the Settings segmented control

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newOnly:  return "New PRs only"
        case .activity: return "PR activity"
        }
    }

    /// One-line explanation under the radio-card heading in onboarding.
    var detail: String {
        switch self {
        case .newOnly:  return "Flags a pull request once, when it first appears. Opening it clears it for good."
        case .activity: return "A read pull request flags again on new activity: commits, reviews, and status changes."
        }
    }
}

/// Which kinds of PR activity re-surface a read PR as unread (Settings → Unread).
/// Every primary signal owns one component of `ReadSignature`; the user's enabled
/// set (persisted on `AppModel.unreadSignals`) decides which components `isUnread`
/// actually compares. Lives here rather than with the Settings enums because the
/// cases and the hashing must stay in lockstep — add a signal and its component
/// definition together.
enum UnreadSignal: String, CaseIterable, Identifiable, Sendable {
    case commits          // head moved — new work pushed
    case baseBranchMerges // modifier on `commits`: base landing in the branch counts too
    case prose            // title or description edited
    case review           // aggregate review decision changed
    case status           // checks / conflicts / draft state changed
    case labels
    case comments

    var id: String { rawValue }

    /// The signals that own a stored component. `baseBranchMerges` isn't one — it
    /// only changes *how* the `commits` component compares (see `isUnread`).
    static let primary: [UnreadSignal] = [.commits, .prose, .review, .status, .labels, .comments]

    /// What ships enabled: the old single-hash behavior, minus base-branch merges
    /// (the reason this setting exists) and label churn.
    static let defaultEnabled: Set<UnreadSignal> = [.commits, .prose, .review, .status]

    /// The Settings checkbox row (Settings → Unread).
    var label: String {
        switch self {
        case .commits:          return "New commits are pushed"
        case .baseBranchMerges: return "Include updates merged from the base branch"
        case .prose:            return "Title or description is edited"
        case .review:           return "Review decision changes"
        case .status:           return "Checks, conflicts, or draft state change"
        case .labels:           return "Labels change"
        case .comments:         return "New comments are posted"
        }
    }
}

/// The per-signal fingerprint read/unread state is tracked against — the read
/// side's counterpart of `VerdictInput.signature`, deliberately its own value:
/// the verdict cache keys on exactly what feeds the prompt, while read state keys
/// on what the user chose to care about, and the two must be free to drift.
///
/// One component per primary `UnreadSignal`, stored per PR when marked read.
/// A PR is unread when any *enabled* signal's stored component no longer matches
/// (`AppModel.isUnread`). Marking read snapshots *all* components — disabled ones
/// too — so enabling a signal later doesn't resurface activity from while it was off.
struct ReadSignature {
    /// Component per primary signal, keyed by `UnreadSignal.rawValue`. `commits`
    /// stores the raw head SHA (the merge walk needs to find it in the recent-commit
    /// window, so it's an identity, not a digest); other small values store raw for
    /// debuggability; free text hashes so the file stays compact.
    let components: [String: String]

    init(_ pr: PullRequest) {
        components = [
            UnreadSignal.commits.rawValue: pr.headOID,
            UnreadSignal.prose.rawValue: Self.hash(pr.title, pr.body),
            UnreadSignal.review.rawValue: pr.reviewState.rawValue,
            UnreadSignal.status.rawValue: Self.hash(
                pr.checksState.rawValue,
                String(pr.mergeable == .conflicting),
                String(pr.isDraft),
                pr.baseBranch, pr.headBranch   // a retarget/rename changes what the PR merges into
            ),
            UnreadSignal.labels.rawValue: Self.hash(pr.labels.joined(separator: ",")),
            UnreadSignal.comments.rawValue: String(pr.commentCount),
        ]
    }

    /// SHA-256, like `VerdictInput.signature` (and for the same reason: `Hasher`'s
    /// per-launch seed wouldn't survive a relaunch).
    private static func hash(_ fields: String...) -> String {
        let raw = fields.joined(separator: "\u{1F}")   // unit separator — can't appear in the fields
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
