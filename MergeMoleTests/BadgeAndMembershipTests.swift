import Foundation
import Testing
@testable import MergeMole

/// The menu-bar number and tab membership — the app's most visible promise.
/// The badge counts unread PRs in the chosen groups, each PR once, honoring
/// the archived-repos filter.
@Suite struct BadgeAndMembershipTests {

    @Test func badgeCountsUnreadInChosenGroupsEachPROnce() async {
        let world = makeWorld { defaults in
            defaults.set(["reviewRequested", "assigned"], forKey: "badgeTabs")
        }
        let both = makePR(id: "PR_1", number: 1, relationships: [.reviewRequested, .assigned])
        let assigned = makePR(id: "PR_2", number: 2, relationships: [.assigned])
        let outside = makePR(id: "PR_3", number: 3, relationships: [.created])
        await world.load([both, assigned, outside])

        #expect(world.model.badgeCount == 2, "PR_1 counts once, PR_3 isn't in a badge group")

        world.model.markRead(world.model.pullRequests.first { $0.id == "PR_1" }!)
        #expect(world.model.badgeCount == 1, "reading a PR empties it out of the count")
    }

    @Test func archivedReposFilterGatesBadgeAndTabs() async {
        let world = makeWorld { defaults in
            defaults.set(false, forKey: "includeArchivedRepos")
        }
        let live = makePR(id: "PR_1", number: 1)
        let archived = makePR(id: "PR_2", number: 2, isArchived: true)
        await world.load([live, archived])

        #expect(world.model.badgeCount == 1)
        #expect(world.model.pullRequests(for: .all).map(\.id) == ["PR_1"])

        world.model.includeArchivedRepos = true
        #expect(world.model.pullRequests(for: .all).count == 2, "the filter is display-only; no refetch needed")
    }

    @Test func tabsMatchByRelationshipAndAllIsTheSuperset() {
        let tabID = UUID()
        let pr = makePR(relationships: [.assigned], customTabIDs: [tabID])
        #expect(PRTab.all.matches(pr))
        #expect(PRTab.assigned.matches(pr))
        #expect(!PRTab.reviewRequested.matches(pr))
        #expect(PRTab.custom(tabID).matches(pr))
        #expect(!PRTab.custom(UUID()).matches(pr))
    }

    @Test func tabDotsFollowUnreadWithinEachTab() async {
        let world = makeWorld()
        let requested = makePR(id: "PR_1", number: 1, relationships: [.reviewRequested])
        let created = makePR(id: "PR_2", number: 2, relationships: [.created])
        await world.load([requested, created])

        #expect(world.model.hasUnread(in: .reviewRequested))
        #expect(world.model.hasUnread(in: .created))

        world.model.markAllRead(in: .reviewRequested)
        #expect(!world.model.hasUnread(in: .reviewRequested), "mark-all is scoped to the tab")
        #expect(world.model.hasUnread(in: .created))
    }
}
