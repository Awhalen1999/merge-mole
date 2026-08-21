import Foundation
import Testing
@testable import MergeMole

/// The desktop-banner rules, one scenario per test. The contract under test:
/// a banner fires exactly when the menu-bar count rises (same pool, same
/// signals, same merge walk), only for changes a fetch itself brought in,
/// once per unread episode — and a banner never outlives its reason.
@Suite struct NotificationTests {

    private let id = "PR_kwDOAbc001"

    private func pr(_ world: TestWorld) -> PullRequest {
        world.model.pullRequests.first { $0.id == id }!
    }

    /// A world with notifications enabled, preseeded like the other preferences
    /// so the key stays part of the spelled-out persistence contract.
    private func notifyingWorld(
        mode: UnreadMode = .activity,
        signals: Set<UnreadSignal>? = nil
    ) -> TestWorld {
        makeWorld(mode: mode, signals: signals) { $0.set(true, forKey: "notificationsEnabled") }
    }

    // MARK: The edge that rings

    @Test func pushOnAReadPRRingsExactlyOnce() async {
        let world = notifyingWorld()
        await world.load([makePR(head: "a1", commits: [.real("a1")])])   // baseline sync
        world.model.markRead(pr(world))

        await world.load([makePR(head: "b2", commits: [.real("a1"), .real("b2")])])
        #expect(world.notifier.delivered.count == 1)
        #expect(world.notifier.delivered.first?.id == id)

        // Still unread at the next fetch — not an edge, so no second ring.
        await world.load([makePR(head: "b2", commits: [.real("a1"), .real("b2")])])
        #expect(world.notifier.delivered.count == 1)
    }

    @Test func firstSyncOfASessionIsQuiet() async {
        // Everything that changed while the app wasn't running lights the
        // badge, never Notification Center — there is no "before" to diff.
        let world = notifyingWorld()
        await world.load([makePR()])
        #expect(world.model.isUnread(pr(world)), "the dot still shows")
        #expect(world.notifier.delivered.isEmpty, "but launch never rings")
    }

    @Test func manualReadUnreadSpamNeverRings() async {
        let world = notifyingWorld()
        await world.load([makePR(head: "a1", commits: [.real("a1")])])
        world.model.markRead(pr(world))
        world.model.markUnread(pr(world))
        world.model.markRead(pr(world))
        world.model.markUnread(pr(world))
        #expect(world.notifier.delivered.isEmpty, "toggling state runs no diff")

        // The PR was already unread (by the user's own hand) when the push
        // landed — not an edge, so even real activity stays quiet now.
        await world.load([makePR(head: "b2", commits: [.real("a1"), .real("b2")])])
        #expect(world.notifier.delivered.isEmpty)
    }

    // MARK: Banners are a subset of the badge

    @Test func changesOutsideTheBadgeGroupsStayQuiet() async {
        // Assigned-only PR, badge groups at their default (Review Requested):
        // the dot may show, but a banner without a badge rise must not exist.
        let world = notifyingWorld()
        await world.load([makePR(head: "a1", commits: [.real("a1")], relationships: [.assigned])])
        world.model.markRead(pr(world))

        await world.load([makePR(head: "b2", commits: [.real("a1"), .real("b2")], relationships: [.assigned])])
        #expect(world.model.isUnread(pr(world)), "the dot flags it")
        #expect(world.notifier.delivered.isEmpty, "the badge didn't rise, so no banner")
    }

    @Test func disabledSignalsDontRing() async {
        let world = notifyingWorld(signals: [.commits])
        await world.load([makePR(comments: 3)])
        world.model.markRead(pr(world))

        await world.load([makePR(comments: 9)])
        #expect(world.notifier.delivered.isEmpty, "banners follow the user's signal choices")
    }

    @Test func mergeOnlyHeadMovesStayQuiet() async {
        // The badge's merge walk applies to banners unchanged: the base branch
        // landing in the PR is not new work, so it neither flags nor rings.
        let world = notifyingWorld()
        await world.load([makePR(head: "a1", commits: [.real("a1")])])
        world.model.markRead(pr(world))

        await world.load([makePR(head: "m2", commits: [.real("a1"), .merge("m2")])])
        #expect(world.notifier.delivered.isEmpty)
    }

    // MARK: Notifications follow the Flag

    @Test func newPRsOnlyFlagQuietsActivityForFree() async {
        // Notifications have no filter of their own: in New-PRs-only Flag mode
        // activity never turns a read PR unread, so only new PRs can ring.
        // The sync with the dot is structural, not implemented.
        let world = notifyingWorld(mode: .newOnly)
        await world.load([makePR(head: "a1", commits: [.real("a1")])])
        world.model.markRead(pr(world))

        // One read PR gets a push; one brand-new PR appears.
        await world.load([
            makePR(head: "b2", commits: [.real("a1"), .real("b2")]),
            makePR(id: "PR_kwDOAbc002", number: 55, title: "Add avatar caching",
                   head: "c1", commits: [.real("c1")]),
        ])
        #expect(world.notifier.delivered.map(\.id) == ["PR_kwDOAbc002"])
        #expect(world.notifier.delivered.first?.body.hasPrefix("New pull request") == true)
    }

    @Test func disabledNeverRingsButTheBadgeStillWorks() async {
        let world = makeWorld()   // notifications ship off
        await world.load([makePR(head: "a1", commits: [.real("a1")])])
        world.model.markRead(pr(world))

        await world.load([makePR(head: "b2", commits: [.real("a1"), .real("b2")])])
        #expect(world.model.isUnread(pr(world)))
        #expect(world.notifier.delivered.isEmpty)
    }

    // MARK: The open panel is the notification

    @Test func openPanelSuppressesBannersForGood() async {
        let world = notifyingWorld()
        await world.load([makePR(head: "a1", commits: [.real("a1")])])
        world.model.markRead(pr(world))

        world.model.panelOpened()
        await world.load([makePR(head: "b2", commits: [.real("a1"), .real("b2")])])
        #expect(world.notifier.delivered.isEmpty, "the user is already looking at the change")

        // Closing the panel doesn't ring retroactively: the PR was unread
        // before the next fetch, so it's no longer an edge.
        world.model.panelClosed()
        await world.load([makePR(head: "b2", commits: [.real("a1"), .real("b2")])])
        #expect(world.notifier.delivered.isEmpty)
    }

    // MARK: A banner never outlives its reason

    @Test func readingAPRSweepsItsBanner() async {
        let world = notifyingWorld()
        await world.load([makePR(head: "a1", commits: [.real("a1")])])
        world.model.markRead(pr(world))
        await world.load([makePR(head: "b2", commits: [.real("a1"), .real("b2")])])
        #expect(world.notifier.delivered.count == 1)

        world.model.markRead(pr(world))
        #expect(world.notifier.removedIDs.contains(id), "catching up clears Notification Center too")
    }

    @Test func clickingABannerCountsAsReading() async {
        let world = notifyingWorld()
        await world.load([makePR(head: "a1", commits: [.real("a1")])])
        world.model.markRead(pr(world))
        await world.load([makePR(head: "b2", commits: [.real("a1"), .real("b2")])])

        world.notifier.click(id)
        #expect(!world.model.isUnread(pr(world)), "the badge drops on the same gesture")
        #expect(world.notifier.removedIDs.contains(id))
    }

    @Test func aDepartedPRSweepsItsBanner() async {
        let world = notifyingWorld()
        await world.load([makePR(head: "a1", commits: [.real("a1")])])
        world.model.markRead(pr(world))
        await world.load([makePR(head: "b2", commits: [.real("a1"), .real("b2")])])
        #expect(world.notifier.delivered.count == 1)

        await world.load([])   // merged or closed between fetches
        #expect(world.notifier.removedIDs.contains(id), "a banner can't point at a PR that's gone")
    }

    // MARK: Permission

    @Test func enablingAsksPermissionDisablingDoesNot() async {
        let world = makeWorld()
        #expect(world.notifier.authorizationRequests == 0, "opted-out installs are never prompted")
        world.model.notificationsEnabled = true
        #expect(world.notifier.authorizationRequests == 1)
        world.model.notificationsEnabled = false
        #expect(world.notifier.authorizationRequests == 1)
    }

    @Test func turningBannersOffSweepsNotificationCenter() async {
        // Off means no MergeMole presence in Notification Center, not just no
        // new banners — whatever was delivered goes with the setting.
        let world = notifyingWorld()
        world.model.notificationsEnabled = false
        #expect(world.notifier.removedAllCount == 1)
    }

    @Test func blockedPermissionSurfacesAndClears() async {
        // The one invisible failure: macOS denies delivery while everything in
        // the app works. The model must reflect the live status both ways so
        // the Settings warning appears, and disappears once the user fixes it.
        let world = notifyingWorld()
        world.notifier.denied = true
        await world.model.refreshNotificationPermission()
        #expect(world.model.notificationsBlocked)

        world.notifier.denied = false
        await world.model.refreshNotificationPermission()
        #expect(!world.model.notificationsBlocked)
    }

    @Test func optedInLaunchEnsuresPermission() async {
        // The enable-time prompt can go unanswered (app quit mid-prompt), which
        // strands macOS at "not determined" and drops every delivery silently.
        // A launch that restores an opted-in mode must re-ask; re-asking is a
        // no-op once the user has actually answered.
        let world = notifyingWorld()
        #expect(world.notifier.authorizationRequests == 1)
    }
}
