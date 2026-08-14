import Foundation
import Testing
@testable import MergeMole

/// The per-signal fingerprint: every primary signal owns exactly one component,
/// each signal's change moves only its own component, and digests are stable
/// across launches. This is the foundation the whole unread system stands on.
@Suite struct ReadSignatureTests {

    @Test func componentsCoverExactlyThePrimarySignals() {
        let components = ReadSignature(makePR()).components
        #expect(Set(components.keys) == Set(UnreadSignal.primary.map(\.rawValue)))
    }

    @Test func commitsComponentIsTheRawHeadSHA() {
        #expect(ReadSignature(makePR(head: "abc123")).components["commits"] == "abc123")
    }

    /// One change per signal; only that signal's component may move. The pairs
    /// drive one parameterized test so a new signal can't dodge the rule.
    static let isolationCases: [(UnreadSignal, PullRequest)] = [
        (.commits,  makePR(head: "bbbb222")),
        (.prose,    makePR(title: "Fix login race on cold start, take two")),
        (.review,   makePR(reviewState: .approved)),
        (.status,   makePR(checksState: .failing)),
        (.labels,   makePR(labels: ["bug", "urgent"])),
        (.comments, makePR(comments: 9)),
    ]

    @Test(arguments: isolationCases.map(\.0))
    func onlyTheChangedSignalsComponentMoves(signal: UnreadSignal) {
        let before = ReadSignature(makePR()).components
        let changed = Self.isolationCases.first { $0.0 == signal }!.1
        let after = ReadSignature(changed).components
        for other in UnreadSignal.primary {
            let moved = after[other.rawValue] != before[other.rawValue]
            #expect(moved == (other == signal), "\(other) moved for a \(signal) change")
        }
    }

    @Test func statusComponentCoversConflictsDraftAndBranches() {
        let base = ReadSignature(makePR()).components["status"]
        #expect(ReadSignature(makePR(mergeable: .conflicting)).components["status"] != base)
        #expect(ReadSignature(makePR(isDraft: true)).components["status"] != base)
        #expect(ReadSignature(makePR(baseBranch: "main")).components["status"] != base)
    }

    /// SHA-256 of fixed input is fixed output — the property `Hasher` lacks
    /// (per-launch seed) and the reason read state survives a relaunch.
    @Test func digestsAreDeterministic() {
        #expect(ReadSignature(makePR()).components == ReadSignature(makePR()).components)
    }

    // MARK: Robust inputs — the world sends worse than ASCII

    @Test func unicodeAndEmojiHashCleanly() {
        let pr = makePR(title: "🚑 Corrige la régression de connexion — 修复登录竞态",
                        body: String(repeating: "naïve café 试验 🧪 ", count: 400))
        let components = ReadSignature(pr).components
        #expect(components.count == UnreadSignal.primary.count)
        #expect(ReadSignature(pr).components == components)
    }

    @Test func emptyFieldsHashCleanly() {
        let pr = makePR(title: "", body: "", head: "", comments: 0, labels: [], commits: [])
        let components = ReadSignature(pr).components
        #expect(components["commits"] == "")
        #expect(Set(components.keys) == Set(UnreadSignal.primary.map(\.rawValue)))
    }

    @Test func controlCharactersInProseDontCrashAndStayIsolated() {
        let pr = makePR(title: "weird\u{1F}title\u{0}with controls", body: "body\u{1F}too")
        let components = ReadSignature(pr).components
        #expect(components["review"] == ReadSignature(makePR()).components["review"])
        #expect(components["prose"] != ReadSignature(makePR()).components["prose"])
    }
}
