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
    let hasConflicts: Bool   // base/head conflict — a real "can't merge as-is" signal
    let additions: Int
    let deletions: Int
    let changedFiles: Int
    let sizeLabel: String
    let labels: [String]
    let isFromFork: Bool          // external contributor — useful review-scope context

    /// Soft, time-/activity-relative context: shown to the model but deliberately
    /// kept OUT of the signature (see `signature`). The card already shows these
    /// live; the verdict treats them as context at analysis time.
    let approvals: Int
    let unresolvedThreads: Int
    let createdAt: Date

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
        hasConflicts = pr.mergeable == .conflicting
        additions = pr.additions
        deletions = pr.deletions
        changedFiles = pr.changedFiles
        sizeLabel = pr.sizeBucket.label
        labels = pr.labels
        isFromFork = pr.isFromFork
        approvals = pr.approvals
        unresolvedThreads = pr.unresolvedThreads
        createdAt = pr.createdAt
        headOID = pr.headOID
    }

    /// The guaranteed-minimum priority from the label/title glossary scan — the
    /// deterministic half of the hybrid. The engine raises the model's call to meet
    /// it (`Verdict.raisingPriority`), and the prompt shows it as a floor the model
    /// may exceed but not undercut.
    var priorityFloor: Priority {
        VerdictGuidance.priorityFloor(title: title, labels: labels)
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
            "Opened: \(Self.age(since: createdAt))",
            "Draft: \(isDraft)",
            "Review state: \(reviewState)",
            "CI: \(checksState)",
            "Changes: +\(additions) / -\(deletions) across \(changedFiles) files (size \(sizeLabel))",
        ]
        if hasConflicts { lines.append("Merge conflicts: yes — needs a rebase before it can merge.") }
        if let activity = reviewActivity { lines.append("Review activity: \(activity)") }
        if isFromFork { lines.append("Opened from a fork (external contributor).") }
        if !labels.isEmpty { lines.append("Labels: \(labels.joined(separator: ", "))") }
        if !body.isEmpty { lines.append("Description:\n\(body)") }
        if priorityFloor > .low {
            lines.append("Priority floor: \(priorityFloor.wireName) — a label/title signal flags this; you may raise it but not go below.")
        }
        return lines.joined(separator: "\n")
    }

    /// Approvals + open review threads, phrased for the prompt — or nil when there's
    /// no review activity worth a line.
    private var reviewActivity: String? {
        var parts: [String] = []
        if approvals > 0 { parts.append("\(approvals) approval\(approvals == 1 ? "" : "s")") }
        if unresolvedThreads > 0 {
            parts.append("\(unresolvedThreads) unresolved review thread\(unresolvedThreads == 1 ? "" : "s")")
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// Coarse, human relative age from the open date. Derived live (not stored), so
    /// it never feeds the signature — age is time, not reviewable content.
    private static func age(since created: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: created, to: Date.now).day ?? 0
        switch days {
        case ..<1:    return "today"
        case 1:       return "yesterday"
        case 2..<14:  return "\(days) days ago"
        case 14..<60: return "\(days / 7) weeks ago"
        default:      return "\(days / 30) months ago"
        }
    }

    /// A stable fingerprint of the PR's **reviewable content** (plus the head SHA). A
    /// mismatch means re-run — and, since the read-store shares this value, re-surface
    /// as unread. So it deliberately excludes the soft context the prompt also shows:
    /// `approvals` / `unresolvedThreads` (would re-run + re-flag on every review click)
    /// and `createdAt`-derived age (time, not content — would churn daily). `isFromFork`
    /// is static, so it's safe to include. Hashed so the cache file stays compact even
    /// with a long description. `Hasher` is unusable here (its seed is randomized per
    /// launch and wouldn't survive a relaunch).
    var signature: String {
        let raw = [
            title, body, repository, author,
            headBranch, baseBranch, headOID,
            String(isDraft), reviewState, checksState, String(hasConflicts),
            String(additions), String(deletions), String(changedFiles),
            sizeLabel, labels.joined(separator: ","), String(isFromFork),
        ].joined(separator: "\u{1F}")   // unit separator — can't appear in the fields
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Keep the description informative but cheap: enough for intent, not the whole
    /// essay. First strip HTML-comment scaffolding (PR templates are full of
    /// `<!-- instructions -->`) so the budget goes to real content; then collapse
    /// whitespace (also stops the signature churning on reflow) and cap. 2000 chars
    /// captures the intent sections of even a robust template while staying well
    /// inside the on-device context window; the long tail (checklists, screenshots)
    /// is the cheap part to drop.
    private static func condensedBody(_ raw: String, limit: Int = 2000) -> String {
        let collapsed = raw
            .replacingOccurrences(of: "<!--[\\s\\S]*?-->", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.count > limit else { return collapsed }
        return collapsed.prefix(limit).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}
