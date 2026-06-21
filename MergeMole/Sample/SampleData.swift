import Foundation

/// Fake but realistic data for Steps 1–2: it lets the whole UI + state pipeline
/// run before any GitHub or AI code exists. `SamplePRProvider` and
/// `SampleVerdictEngine` are the only things that read from here, so deleting
/// this file later removes the fakes in one move.
enum SampleData {

    /// Stand-in for the signed-in user. Real value comes from the GitHub viewer
    /// at Step 3; for now it lets the tab filters (mine / needs-review) mean
    /// something against fake data.
    static let currentUser = "you"

    static let pullRequests: [PullRequest] = [
        PullRequest(
            id: "PR_1",
            number: 482,
            title: "Fix race condition in session refresh",
            body: "Guards the token-refresh path with an actor so concurrent requests can't double-refresh. Adds a regression test.",
            repository: "acme/web-platform",
            author: "dana",
            headBranch: "fix/session-race",
            baseBranch: "main",
            headOID: "a1b2c3d",
            isDraft: false,
            reviewState: .pending,
            checksState: .passing,
            additions: 34, deletions: 12, changedFiles: 3,
            labels: ["bug"],
            url: URL(string: "https://github.com/acme/web-platform/pull/482")!,
            updatedAt: date(minutesAgo: 18)
        ),
        PullRequest(
            id: "PR_2",
            number: 1190,
            title: "Migrate billing service to the new event bus",
            body: "Moves billing off the legacy queue onto the new event bus. Touches the charge and invoice paths; retry semantics need a careful look.",
            repository: "acme/payments",
            author: "marco",
            headBranch: "feat/event-bus-billing",
            baseBranch: "main",
            headOID: "b2c3d4e",
            isDraft: false,
            reviewState: .pending,
            checksState: .failing,
            additions: 1840, deletions: 920, changedFiles: 47,
            labels: ["enhancement", "needs-discussion"],
            url: URL(string: "https://github.com/acme/payments/pull/1190")!,
            updatedAt: date(minutesAgo: 95)
        ),
        PullRequest(
            id: "PR_3",
            number: 77,
            title: "Bump SwiftLint to 0.55 and fix new warnings",
            body: "Routine lint bump — mostly autofixes plus two manual rule suppressions.",
            repository: "acme/ios-app",
            author: currentUser,
            headBranch: "chore/swiftlint-0.55",
            baseBranch: "develop",
            headOID: "c3d4e5f",
            isDraft: false,
            reviewState: .changesRequested,
            checksState: .passing,
            additions: 6, deletions: 4, changedFiles: 2,
            labels: ["chore"],
            url: URL(string: "https://github.com/acme/ios-app/pull/77")!,
            updatedAt: date(minutesAgo: 240)
        ),
        PullRequest(
            id: "PR_4",
            number: 305,
            title: "WIP: redesign onboarding flow",
            body: "Early draft of the new onboarding. Layout still in flux — not ready for review yet.",
            repository: "acme/ios-app",
            author: currentUser,
            headBranch: "feat/onboarding-redesign",
            baseBranch: "develop",
            headOID: "d4e5f6a",
            isDraft: true,
            reviewState: .pending,
            checksState: .pending,
            additions: 612, deletions: 88, changedFiles: 21,
            labels: [],
            url: URL(string: "https://github.com/acme/ios-app/pull/305")!,
            updatedAt: date(minutesAgo: 1440)
        ),
        PullRequest(
            id: "PR_5",
            number: 56,
            title: "Add dark-mode tokens to the design system",
            body: "Adds dark-mode color tokens to the design system. Pure additions — no existing tokens changed.",
            repository: "acme/design-system",
            author: "priya",
            headBranch: "feat/dark-mode-tokens",
            baseBranch: "main",
            headOID: "e5f6a7b",
            isDraft: false,
            reviewState: .approved,
            checksState: .passing,
            additions: 210, deletions: 30, changedFiles: 9,
            labels: ["design"],
            url: URL(string: "https://github.com/acme/design-system/pull/56")!,
            updatedAt: date(minutesAgo: 30)
        ),
    ]

    /// A deterministic stand-in for a real AI verdict. Derives effort from the
    /// native size and priority from review/CI signals — close enough to make
    /// the card look alive before the Foundation Models engine lands at Step 5.
    static func verdict(for pr: PullRequest) -> Verdict {
        let effort: EffortTier
        switch pr.sizeBucket {
        case .xs: effort = .trivial
        case .s:  effort = .easy
        case .m:  effort = .moderate
        case .l:  effort = .involved
        case .xl: effort = .heavy
        }

        let priority: Priority
        let rationale: String
        if pr.isDraft {
            priority = .low
            rationale = "Still a draft — not ready for review yet."
        } else if pr.checksState == .failing {
            priority = .low
            rationale = "CI is red; wait for the author to fix it."
        } else if pr.reviewState == .pending && pr.checksState == .passing {
            priority = pr.sizeBucket <= .s ? .high : .normal
            rationale = pr.sizeBucket <= .s
                ? "Small, green, and waiting — a quick win to clear."
                : "Green and waiting on your review."
        } else if pr.reviewState == .changesRequested {
            priority = .normal
            rationale = "Changes already requested; just a re-check."
        } else {
            priority = .low
            rationale = "Already approved — nothing blocking from you."
        }

        return Verdict(
            effort: effort,
            priority: priority,
            summary: summary(for: pr),
            rationale: rationale
        )
    }

    private static func summary(for pr: PullRequest) -> String {
        "Touches \(pr.changedFiles) file\(pr.changedFiles == 1 ? "" : "s") in \(pr.repository.split(separator: "/").last.map(String.init) ?? pr.repository)."
    }

    /// Sample timestamps as live ages so the demo reads naturally ("18m", "4h").
    /// Real PRs use `updatedAt` straight from the API.
    private static func date(minutesAgo minutes: Int) -> Date {
        Date.now.addingTimeInterval(TimeInterval(-minutes * 60))
    }
}
