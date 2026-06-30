import Foundation

/// The single source of truth for *how* every engine triages a PR — the system
/// instructions, the format rules for each of the three outputs, and the
/// keyword/label glossary behind the deterministic priority floor.
///
/// Both engines feed off the same `systemPrompt`, so an on-device verdict and a
/// bring-your-own verdict read the same and can't drift in style. The model never
/// sees the diff — only the metadata + description `VerdictInput` assembles — so
/// the spec is written for that reality.
enum VerdictGuidance {

    /// Shared system instructions for both engines. Behaviour only — no response
    /// *format* (the on-device engine uses guided generation, the remote engine
    /// appends its own JSON instruction), so this stays engine-agnostic.
    static let systemPrompt = """
    You triage GitHub pull requests for a busy reviewer. From each PR's metadata and \
    description (you do NOT see the code diff), produce three things.

    PRIORITY: how urgently the reviewer should look. Be conservative: most PRs are \
    "normal". Reserve "high" and "urgent" for clear, specific signals. If a PR looks \
    routine, it is "normal" (or "low"). Never inflate; if everything were urgent, the \
    signal would be worthless.
      • urgent: production-impacting or blocking work (hotfix, outage, security fix, \
    data-loss risk, revert, or anything explicitly marked blocking / P0 / SEV).
      • high: important and time-sensitive work (regressions, release- or \
    deadline-bound work, breaking changes, risky migrations, or changes-requested \
    needing a quick turnaround).
      • normal: the default (ordinary features, refactors, routine fixes).
      • low: trivial or non-pressing (docs, chores, dependency bumps, drafts).
    The input may carry a "Priority floor" set by a label/title scan. You may raise \
    the priority above it when the content clearly warrants, but never below it.

    SUMMARY: one plain line of what the PR does. Start with a present-tense verb, at \
    most 14 words, no "This PR" preamble, no trailing period, and don't merely restate \
    the title. Be concrete about the change.

    REVIEW: one short sentence, at most 25 words, naming the single biggest thing to \
    watch or where to look first. A quick peek to set up the review, not a full \
    analysis. Don't enumerate every risk, don't restate the summary, don't pad. No \
    trailing period.

    Write in plain, natural language. NEVER use an em dash (—) in the summary or \
    review; use a comma, a period, or "and" instead. Never invent details the input \
    doesn't support. If the description is thin, judge from the title, size, file \
    count, and labels.

    Examples (input gives priority / summary / review):
      • "Bump lodash 4.17.20 to 4.17.21", XS, no description: low / "Update lodash to \
    4.17.21" / "Trivial dependency bump, safe to skim the lockfile and merge"
      • "Fix login redirect loop on expired session", label hotfix: urgent / "Stop \
    the redirect loop when a session expires" / "Auth-path hotfix, so verify the \
    expiry case and watch for regressions"
      • "Add CSV export to the reports page", M, clear description: normal / "Add CSV \
    export to the reports page" / "Self-contained feature, so check the export format \
    and empty state"
      • "Refactor billing onto the new event bus", L, 22 files, 2 unresolved threads: \
    high / "Move billing onto the new event bus" / "Large, high-blast-radius change \
    with open feedback, so resolve the threads and trace the charge path first"
    """

    // MARK: Priority floor (the deterministic half of the hybrid)

    /// Tokens that, in a label or the title, force at least `.urgent`.
    private static let urgentTokens = [
        "blocking", "blocker", "hotfix", "urgent", "p0", "sev0", "sev1",
        "outage", "prod down", "revert", "security", "cve", "critical", "emergency",
    ]

    /// Tokens that force at least `.high`.
    private static let highTokens = [
        "regression", "p1", "release", "deadline", "breaking change",
        "data loss", "migration", "time-sensitive", "time sensitive",
    ]

    /// The guaranteed minimum priority from a word-boundary scan of the **labels and
    /// title** only — the deliberate, low-false-positive signals. (Body mentions are
    /// left to the model: it reads the full description and can escalate, but an
    /// incidental "not a hotfix" in prose won't force the tag.) Returns `.low` when
    /// nothing matches, which imposes no floor at all.
    static func priorityFloor(title: String, labels: [String]) -> Priority {
        let haystack = (labels + [title]).joined(separator: " ").lowercased()
        func mentions(_ tokens: [String]) -> Bool {
            tokens.contains { token in
                haystack.range(
                    of: "\\b\(NSRegularExpression.escapedPattern(for: token))\\b",
                    options: .regularExpression
                ) != nil
            }
        }
        if mentions(urgentTokens) { return .urgent }
        if mentions(highTokens) { return .high }
        return .low
    }
}
