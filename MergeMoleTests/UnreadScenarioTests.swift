import Foundation
import Testing
@testable import MergeMole

/// The unread state machine, one scenario per test: a real `AppModel` fed by a
/// scripted fake provider, each test reading as read → event → verdict. These
/// encode the rules the feature was designed around; if one fails, behavior
/// users can see has changed.
@Suite struct UnreadScenarioTests {

    private let id = "PR_kwDOAbc001"
    private func unread(_ world: TestWorld) -> Bool {
        world.model.isUnread(world.model.pullRequests.first { $0.id == id }!)
    }
    private func markRead(_ world: TestWorld) {
        world.model.markRead(world.model.pullRequests.first { $0.id == id }!)
    }

    // MARK: Commits and the merge walk

    @Test func baseMergeStaysRead() async {
        let world = makeWorld()
        await world.load([makePR(head: "a1", commits: [.real("a1")])])
        markRead(world)

        await world.load([makePR(head: "m2", commits: [.real("a1"), .merge("m2")])])
        #expect(!unread(world), "an update from the base branch is not new work")
    }

    @Test func realPushFlags() async {
        let world = makeWorld()
        await world.load([makePR(head: "a1", commits: [.real("a1")])])
        markRead(world)

        await world.load([makePR(head: "b2", commits: [.real("a1"), .real("b2")])])
        #expect(unread(world))
    }

    @Test func pushBuriedUnderAMergeStillFlags() async {
        let world = makeWorld()
        await world.load([makePR(head: "a1", commits: [.real("a1")])])
        markRead(world)

        // A real commit and a base merge both landed between fetches. The merge
        // sits at the head, but the walk sees the real commit behind it.
        await world.load([makePR(head: "m3", commits: [.real("a1"), .real("b2"), .merge("m3")])])
        #expect(unread(world), "a merge on top must never hide a real push")
    }

    @Test func headOutsideTheWalkWindowFlagsConservatively() async {
        let world = makeWorld()
        await world.load([makePR(head: "a1", commits: [.real("a1")])])
        markRead(world)

        // So much landed that the stored head fell out of the fetched window —
        // even though everything visible is a merge, we can't prove the gap was.
        let window = (2...21).map { PRCommit.merge("m\($0)") }
        await world.load([makePR(head: "m21", commits: window)])
        #expect(unread(world))
    }

    @Test func forcePushFlags() async {
        let world = makeWorld()
        await world.load([makePR(head: "a1", commits: [.real("a1")])])
        markRead(world)

        await world.load([makePR(head: "z9", commits: [.real("z9")])])   // history rewritten
        #expect(unread(world))
    }

    @Test func mergeOnlyMovesAreAbsorbedSoTheWindowStaysFresh() async {
        let world = makeWorld()
        await world.load([makePR(head: "a1", commits: [.real("a1")])])
        markRead(world)

        // Two merge-only advances, the second with the original head already out
        // of the window. Each fetch absorbs the move, so the stored head keeps up.
        await world.load([makePR(head: "m2", commits: [.real("a1"), .merge("m2")])])
        #expect(!unread(world))
        await world.load([makePR(head: "m3", commits: [.merge("m2"), .merge("m3")])])
        #expect(!unread(world), "absorbed merges keep the stored head inside the window")

        await world.load([makePR(head: "r4", commits: [.merge("m3"), .real("r4")])])
        #expect(unread(world), "the next real push still flags")
    }

    @Test func baseBranchToggleCountsMergesAsNew() async {
        let world = makeWorld(signals: UnreadSignal.defaultEnabled.union([.baseBranchMerges]))
        await world.load([makePR(head: "a1", commits: [.real("a1")])])
        markRead(world)

        await world.load([makePR(head: "m2", commits: [.real("a1"), .merge("m2")])])
        #expect(unread(world), "opting in makes base merges count")
    }

    // MARK: Settings never rewrite history

    @Test func togglingSignalsNeverFlipsReadState() async {
        let world = makeWorld()
        await world.load([makePR()])
        markRead(world)

        world.model.unreadSignals.insert(.labels)
        world.model.unreadSignals.remove(.commits)
        world.model.unreadSignals.insert(.commits)
        #expect(!unread(world), "a read PR stays read through any toggle")

        await world.load([makePR(title: "Retitled while unread")])
        #expect(unread(world))
        world.model.unreadSignals.insert(.comments)
        #expect(unread(world), "an unread PR stays unread through any toggle")
    }

    @Test func enablingASignalLaterDoesNotResurfaceOldActivity() async {
        let world = makeWorld()   // comments signal off by default
        await world.load([makePR(comments: 3)])
        markRead(world)

        await world.load([makePR(comments: 9)])   // discussion while the signal is off
        #expect(!unread(world))

        world.model.unreadSignals.insert(.comments)
        #expect(!unread(world), "the off-period chatter is water under the bridge")

        await world.load([makePR(comments: 12)])
        #expect(unread(world), "new comments after enabling do flag")
    }

    // MARK: New-only mode

    @Test func newOnlyModeSeenOnceIsSeenForever() async {
        let world = makeWorld(mode: .newOnly)
        await world.load([makePR(head: "a1", commits: [.real("a1")])])
        #expect(unread(world), "a PR you never opened is new")
        markRead(world)

        await world.load([makePR(title: "Retitled", head: "b2", reviewState: .approved,
                                 comments: 40, commits: [.real("a1"), .real("b2")])])
        #expect(!unread(world), "no activity of any kind re-flags in New-only mode")
    }

    @Test func newOnlyModeStillFlagsBrandNewPRs() async {
        let world = makeWorld(mode: .newOnly)
        await world.load([makePR()])
        markRead(world)

        let newcomer = makePR(id: "PR_kwDOAbc002", number: 42)
        await world.load([makePR(), newcomer])
        #expect(world.model.isUnread(world.model.pullRequests.first { $0.id == newcomer.id }!))
        #expect(!unread(world))
    }

    // MARK: Real-world shapes — fetches are bundles, not single changes

    @Test func correlatedActivityBurstFlagsOnceAndReadsOnce() async {
        let world = makeWorld()
        await world.load([makePR(head: "a1", commits: [.real("a1")])])
        markRead(world)

        // A real fetch after a busy hour: a push landed together with a review,
        // CI restarting, and fresh discussion — one bundle, not four events.
        let burst = makePR(head: "b2", reviewState: .approved, checksState: .pending,
                           comments: 14, commits: [.real("a1"), .real("b2")])
        await world.load([burst])
        #expect(unread(world))

        markRead(world)
        #expect(!unread(world), "one read absorbs the whole bundle")
    }

    @Test func timestampDriftAloneNeverFlags() async {
        let world = makeWorld()
        await world.load([makePR()])
        markRead(world)

        // The most common fetch of all: GitHub touched `updatedAt` (thread
        // activity we don't track, a base push, anything) and nothing else.
        var touched = makePR()
        touched.updatedAt = Date(timeIntervalSince1970: 1_700_200_000)
        await world.load([touched])
        #expect(!unread(world), "time is not content")
    }

    /// Pins today's deliberate semantics: "checks change" includes checks
    /// *finishing*, so a PR triaged mid-CI re-flags when the run completes —
    /// even on success. If that ever proves too noisy in practice, the lever is
    /// the status component in `ReadSignature` (fold `.pending` into the
    /// previous state, or flag only on `.failing`), and this test is the line
    /// to flip alongside it.
    @Test func ciFinishingReflagsAPRReadMidRun() async {
        let world = makeWorld()
        await world.load([makePR(checksState: .pending)])
        markRead(world)   // triaged while checks were still running

        await world.load([makePR(checksState: .passing)])
        #expect(unread(world))
    }

    // MARK: Manual marks, seeding, migration, pruning

    @Test func markUnreadFlagsUntilReopened() async {
        let world = makeWorld()
        await world.load([makePR()])
        markRead(world)
        #expect(!unread(world))

        world.model.markUnread(world.model.pullRequests[0])
        #expect(unread(world))
        markRead(world)
        #expect(!unread(world))
    }

    @Test func firstSyncSeedsEverythingReadExactlyOnce() async {
        let world = makeWorld(seeded: false)
        await world.load([makePR(), makePR(id: "PR_kwDOAbc002", number: 42)])
        #expect(world.model.pullRequests.allSatisfy { !world.model.isUnread($0) },
                "a new user must not open to a wall of unread")

        let later = makePR(id: "PR_kwDOAbc003", number: 43)
        await world.load([makePR(), makePR(id: "PR_kwDOAbc002", number: 42), later])
        #expect(world.model.isUnread(world.model.pullRequests.first { $0.id == later.id }!),
                "seeding happens once, not on every sync")
    }

    @Test func legacyV1EntryBackfillsReadThenTracksNormally() async throws {
        let url = tempFileURL("read-state.json")
        try Data(#"{"PR_kwDOAbc001": "deadbeef"}"#.utf8).write(to: url)   // pre-1.4 format

        let world = makeWorld(readStoreURL: url)
        await world.load([makePR(head: "a1", commits: [.real("a1")])])
        #expect(!unread(world), "a PR read before the upgrade stays read")

        await world.load([makePR(head: "b2", commits: [.real("a1"), .real("b2")])])
        #expect(unread(world), "backfilled components track new activity")
    }

    @Test func disappearedPRsArePrunedFromTheStore() async {
        let world = makeWorld()
        await world.load([makePR()])
        markRead(world)

        await world.load([])   // merged or closed
        #expect(world.model.readComponents[id] == nil, "the map tracks only the live set")
    }

    @Test func readStateSurvivesARelaunch() async {
        let url = tempFileURL("read-state.json")
        let first = makeWorld(readStoreURL: url)
        await first.load([makePR()])
        first.model.markRead(first.model.pullRequests[0])

        let second = makeWorld(readStoreURL: url)   // fresh model, same disk
        await second.load([makePR()])
        #expect(!unread(second))
    }

    @Test func failedFetchLeavesEverythingIntact() async {
        let world = makeWorld()
        await world.load([makePR()])
        markRead(world)

        world.provider.error = URLError(.notConnectedToInternet)
        await world.model.load()
        #expect(world.model.loadError != nil)
        #expect(world.model.pullRequests.count == 1, "the stale list stays visible")
        #expect(!unread(world), "a failed fetch never corrupts read state")
    }
}
