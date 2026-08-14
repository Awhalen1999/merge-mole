import Foundation
import Testing
@testable import MergeMole

/// The GitHub boundary, tested from a captured-response fixture: field mapping,
/// bucket merging, custom-tab tagging, and the tolerances (junk nodes, dead
/// buckets) that keep one bad search from wiping the panel. No network involved.
@Suite struct ProviderDecodeTests {

    /// One realistic GraphQL response: PR_A rich and in two buckets, PR_B minimal
    /// (draft, archived repo, authored by the viewer) in created + reviewed +
    /// custom0, a junk node search can return, and a dead bucket.
    static let fixture = Data("""
    {
      "data": {
        "viewer": { "login": "tester", "avatarUrl": null },
        "reviewRequested": { "nodes": [
          { "id": null },
          {
            "id": "PR_A", "number": 7, "title": "Throttle webhook retries",
            "bodyText": "Adds jittered backoff to webhook delivery.",
            "isDraft": false,
            "url": "https://github.com/acme/hooks/pull/7",
            "createdAt": "2026-07-30T09:00:00Z", "updatedAt": "2026-08-01T12:00:00Z",
            "additions": 210, "deletions": 40, "changedFiles": 8,
            "mergeable": "CONFLICTING", "mergeStateStatus": "BEHIND",
            "authorAssociation": "MEMBER", "isCrossRepository": true,
            "totalCommentsCount": 5, "viewerDidAuthor": false,
            "reviewThreads": { "nodes": [
              { "isResolved": true }, { "isResolved": false }, { "isResolved": false }
            ]},
            "latestOpinionatedReviews": { "nodes": [
              { "state": "APPROVED" }, { "state": "COMMENTED" }
            ]},
            "reviewRequests": { "nodes": [
              { "requestedReviewer": { "__typename": "User", "login": "kai", "avatarUrl": "https://avatars.example/kai" } },
              { "requestedReviewer": null }
            ]},
            "repository": { "nameWithOwner": "acme/hooks", "isArchived": false },
            "author": { "login": "nova", "avatarUrl": "https://avatars.example/nova" },
            "headRefName": "fix/backoff", "baseRefName": "dev", "headRefOid": "feed01",
            "reviewDecision": "APPROVED",
            "labels": { "nodes": [ { "name": "bug" }, { "name": "api" } ] },
            "commits": { "totalCount": 3, "nodes": [
              { "commit": { "statusCheckRollup": { "state": "SUCCESS" } } }
            ]},
            "recentCommits": { "nodes": [
              { "commit": { "oid": "aaa001", "parents": { "totalCount": 1 } } },
              { "commit": { "oid": "feed01", "parents": { "totalCount": 2 } } }
            ]}
          }
        ]},
        "assigned": { "nodes": [ { "id": "PR_A" } ] },
        "created": { "nodes": [
          {
            "id": "PR_B", "number": 8, "title": "Draft: sketch new panel header",
            "isDraft": true, "viewerDidAuthor": true,
            "url": "https://github.com/acme/hooks/pull/8",
            "repository": { "nameWithOwner": "acme/hooks", "isArchived": true },
            "headRefOid": "beef02"
          }
        ]},
        "mentioned": null,
        "reviewed": { "nodes": [ { "id": "PR_B", "viewerDidAuthor": true } ] },
        "custom0": { "nodes": [ { "id": "PR_B" } ] }
      }
    }
    """.utf8)

    static let customTab = CustomTab(name: "Panel work", query: "label:panel")

    private func result() throws -> PRFetchResult {
        try GitHubAPI.fetchResult(from: Self.fixture, customTabs: [Self.customTab])
    }

    @Test func mapsEveryFieldTheAppReads() throws {
        let prA = try #require(try result().pullRequests.first { $0.id == "PR_A" })
        #expect(prA.title == "Throttle webhook retries")
        #expect(prA.headOID == "feed01")
        #expect(prA.reviewState == .approved)
        #expect(prA.checksState == .passing)
        #expect(prA.mergeable == .conflicting)
        #expect(prA.isBehindBase)
        #expect(prA.isFromFork)
        #expect(prA.commentCount == 5)
        #expect(prA.resolvedThreads == 1 && prA.unresolvedThreads == 2)
        #expect(prA.approvals == 1, "only APPROVED reviews count")
        #expect(prA.labels == ["bug", "api"])
        #expect(prA.requestedReviewers.map(\.login) == ["kai"], "team/bot reviewers are skipped")
        #expect(prA.commitCount == 3)
    }

    /// The field the merge walk lives on: parent count becomes `isMerge`.
    @Test func mapsRecentCommitsWithMergeDetection() throws {
        let prA = try #require(try result().pullRequests.first { $0.id == "PR_A" })
        #expect(prA.recentCommits == [PRCommit(oid: "aaa001", isMerge: false),
                                      PRCommit(oid: "feed01", isMerge: true)])
    }

    @Test func mergesBucketsIntoOneRelationshipSet() throws {
        let prA = try #require(try result().pullRequests.first { $0.id == "PR_A" })
        #expect(prA.relationships == [.reviewRequested, .assigned])
    }

    /// GitHub's `reviewed-by:@me` returns your own PRs; those stay under Created.
    @Test func ownPRsNeverGetTheReviewedTag() throws {
        let prB = try #require(try result().pullRequests.first { $0.id == "PR_B" })
        #expect(prB.relationships == [.created])
        #expect(prB.customTabIDs == [Self.customTab.id])
    }

    @Test func minimalNodesFallBackToDefaultsInsteadOfDropping() throws {
        let prB = try #require(try result().pullRequests.first { $0.id == "PR_B" })
        #expect(prB.isDraft && prB.isArchived)
        #expect(prB.recentCommits.isEmpty && prB.labels.isEmpty && prB.commentCount == 0)
        #expect(prB.checksState == .unknown && prB.mergeable == .unknown)
    }

    @Test func junkNodesAndDeadBucketsAreTolerated() throws {
        let prs = try result().pullRequests
        #expect(prs.count == 2, "the id-less node is dropped; the null bucket costs nothing")
    }

    @Test func viewerComesAlongForTheRide() throws {
        #expect(try result().viewer == "tester")
    }
}

/// The whole pipe on real-shaped data: fixture JSON → provider assembly → model
/// → unread state and the badge. The decode tests and the scenario tests prove
/// the two halves separately; this proves they agree in practice, not in theory.
@Suite struct FixtureToPanelTests {

    @Test func fixtureFlowsThroughToUnreadAndTheBadge() async throws {
        let assembled = try GitHubAPI.fetchResult(
            from: ProviderDecodeTests.fixture,
            customTabs: [ProviderDecodeTests.customTab]
        ).pullRequests

        let world = makeWorld()
        await world.load(assembled)

        #expect(world.model.pullRequests(for: .all).count == 2)
        #expect(world.model.badgeCount == 1, "PR_A awaits your review; PR_B is your own")
        #expect(world.model.pullRequests(for: .custom(ProviderDecodeTests.customTab.id)).map(\.id) == ["PR_B"])

        world.model.markRead(world.model.pullRequests.first { $0.id == "PR_A" }!)
        #expect(world.model.badgeCount == 0, "reading the review request empties the menu-bar count")
    }
}

/// The query builder: custom searches travel as variables (user input can never
/// become GraphQL syntax) and always arrive scoped to PRs.
@Suite struct QueryBuilderTests {

    @Test func customTabsBecomeNumberedVariables() {
        let query = GitHubAPI.prQuery(customCount: 2)
        #expect(query.contains("$q0: String!") && query.contains("$q1: String!"))
        #expect(query.contains("custom0: search(query: $q0") && query.contains("custom1: search(query: $q1"))
    }

    @Test func zeroCustomTabsMeansNoParameterList() {
        #expect(GitHubAPI.prQuery(customCount: 0).hasPrefix("query {"))
    }

    @Test func wireQueryScopesToPRsAndDefaultsTheSort() {
        #expect(GitHubAPI.wireQuery("label:api") == "is:pr label:api sort:updated-desc")
        #expect(GitHubAPI.wireQuery("repo:acme/hooks sort:created-asc") == "is:pr repo:acme/hooks sort:created-asc",
                "a user-chosen sort is honored")
    }
}

/// Contract tripwires: the verdict-cache key, its keying rules, and the
/// deterministic priority floor. These guard promises other code relies on.
@Suite struct VerdictContractTests {

    /// Golden hash: if this fails, `VerdictInput.signature` changed — which
    /// invalidates every user's verdict cache and re-runs the AI across the
    /// board. Change it knowingly or not at all. (Read state has its own
    /// signature and must never be re-coupled to this one.)
    @Test func verdictSignatureIsPinned() {
        #expect(VerdictInput(makePR()).signature ==
                "e5b47846634aeb274aa7f027e0631ab5f1ba80b93efdc35b63eb1165b7629c3f")
    }

    @Test func verdictSignatureIgnoresChatterButTracksTheHead() {
        let base = VerdictInput(makePR()).signature
        #expect(VerdictInput(makePR(comments: 99)).signature == base, "comments are chatter")
        #expect(VerdictInput(makePR(head: "bbb222")).signature != base, "a push re-runs")
    }

    @Test func cacheHitsOnlyWhileContentMatches() {
        let cache = VerdictCache(fileURL: tempFileURL("verdict-cache.json"))
        let verdict = Verdict(priority: .high, summary: "Throttles webhook retries", rationale: "Check the backoff bounds")
        cache.store(verdict, for: makePR(), engine: "on-device@3")

        #expect(cache.verdict(for: makePR(), engine: "on-device@3") == verdict)
        #expect(cache.verdict(for: makePR(head: "bbb222"), engine: "on-device@3") == nil, "content changed → re-run")
        #expect(cache.verdict(for: makePR(), engine: "gpt@3") == nil, "engines never serve each other")
    }

    @Test func cachePersistsAndPrunesToLivePRsOnCurrentVersion() {
        let url = tempFileURL("verdict-cache.json")
        let cache = VerdictCache(fileURL: url)
        let verdict = Verdict(priority: .normal, summary: "s", rationale: "r")
        cache.store(verdict, for: makePR(), engine: "on-device@3")
        cache.store(verdict, for: makePR(id: "PR_gone", number: 9), engine: "on-device@3")
        cache.persist()

        let reloaded = VerdictCache(fileURL: url)
        #expect(reloaded.verdict(for: makePR(), engine: "on-device@3") == verdict)

        reloaded.prune(toCurrent: [makePR()], version: "3")
        #expect(reloaded.verdict(for: makePR(id: "PR_gone", number: 9), engine: "on-device@3") == nil)
        reloaded.prune(toCurrent: [makePR()], version: "4")
        #expect(reloaded.verdict(for: makePR(), engine: "on-device@3") == nil, "a version bump clears old-prompt entries")
    }

    @Test func priorityFloorReadsLabelsAndTitleOnly() {
        #expect(VerdictGuidance.priorityFloor(title: "Hotfix: checkout outage", labels: []) == .urgent)
        #expect(VerdictGuidance.priorityFloor(title: "Fix scroll jitter", labels: ["regression"]) == .high)
        #expect(VerdictGuidance.priorityFloor(title: "Update README badges", labels: ["docs"]) == .low)
        #expect(VerdictGuidance.priorityFloor(title: "Not urgently needed cleanup", labels: []) == .low,
                "word boundaries, not substrings: 'urgently' is not 'urgent'")
    }

    @Test func priorityFloorOnlyEverRaises() {
        let verdict = Verdict(priority: .low, summary: "s", rationale: "r")
        #expect(verdict.raisingPriority(toAtLeast: .high).priority == .high)
        let urgent = Verdict(priority: .urgent, summary: "s", rationale: "r")
        #expect(urgent.raisingPriority(toAtLeast: .normal).priority == .urgent)
    }
}
