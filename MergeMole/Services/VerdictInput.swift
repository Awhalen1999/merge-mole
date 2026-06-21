import Foundation
import CryptoKit

/// The exact, engine-agnostic context a verdict is computed from — and nothing
/// else. This is the single source of truth that keeps two things in lockstep
/// which used to be maintained by hand in three separate places:
///
///   • what each engine puts in its prompt   → `promptText`
///   • what the cache treats as "changed"     → `signature`
///
/// Because both derive from this one value, the cache can never serve a verdict
/// that was computed from different inputs than the ones now true for the PR.
/// Add a field here and both the prompt and the cache key pick it up — no
/// chance of the "I updated the prompt but forgot the signature" stale-cache bug.
struct VerdictInput {
    let title: String
    let body: String
    let repository: String
    let author: String
    let headBranch: String
    let baseBranch: String
    let isDraft: Bool
    let reviewState: String
    let checksState: String
    let additions: Int
    let deletions: Int
    let changedFiles: Int
    let sizeLabel: String
    let labels: [String]

    /// Head commit SHA. Feeds the **signature only** (never the prompt — the model
    /// has no use for a hash). This is what makes a new commit reliably re-analyze:
    /// the SHA changes on every push, including in-place edits the line counts miss.
    let headOID: String

    init(_ pr: PullRequest) {
        title = pr.title
        body = Self.condensedBody(pr.body)
        repository = pr.repository
        author = pr.author
        headBranch = pr.headBranch
        baseBranch = pr.baseBranch
        isDraft = pr.isDraft
        reviewState = pr.reviewState.rawValue
        checksState = pr.checksState.rawValue
        additions = pr.additions
        deletions = pr.deletions
        changedFiles = pr.changedFiles
        sizeLabel = pr.sizeBucket.label
        labels = pr.labels
        headOID = pr.headOID
    }

    /// The context block shown to the model — identical across engines, so the
    /// on-device and BYO models judge from exactly the same facts. Optional rows
    /// (labels, description) only appear when present, so the prompt stays tight.
    var promptText: String {
        var lines = [
            "Title: \(title)",
            "Repository: \(repository)",
            "Author: \(author)",
            "Branch: \(headBranch) -> \(baseBranch)",
            "Draft: \(isDraft)",
            "Review state: \(reviewState)",
            "CI: \(checksState)",
            "Changes: +\(additions) / -\(deletions) across \(changedFiles) files (size \(sizeLabel))",
        ]
        if !labels.isEmpty { lines.append("Labels: \(labels.joined(separator: ", "))") }
        if !body.isEmpty { lines.append("Description:\n\(body)") }
        return lines.joined(separator: "\n")
    }

    /// A stable fingerprint of every input above (plus the head SHA). A mismatch
    /// means the PR's reviewable content changed → re-run. Hashed so the cache
    /// file stays compact even with a long description. `Hasher` is unusable here
    /// (its seed is randomized per launch and wouldn't survive a relaunch).
    var signature: String {
        let raw = [
            title, body, repository, author,
            headBranch, baseBranch, headOID,
            String(isDraft), reviewState, checksState,
            String(additions), String(deletions), String(changedFiles),
            sizeLabel, labels.joined(separator: ","),
        ].joined(separator: "\u{1F}")   // unit separator — can't appear in the fields
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Keep the description informative but cheap: enough for intent, not the whole
    /// essay. Collapsing whitespace also stops the signature churning on reflow.
    private static func condensedBody(_ raw: String, limit: Int = 500) -> String {
        let collapsed = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.count > limit else { return collapsed }
        return collapsed.prefix(limit).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}
