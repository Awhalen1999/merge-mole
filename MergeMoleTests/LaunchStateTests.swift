import Foundation
import Testing
@testable import MergeMole

/// Launch-time reconciliation of persisted preferences: restoring the tab order
/// while merging tabs a newer build shipped, dropping deleted custom tabs, and
/// deduping defensively. This runs on every launch; a bug here scrambles every
/// user's tab bar on upgrade.
@Suite struct LaunchStateTests {

    /// A model built from preseeded defaults — these tests are about what `init`
    /// makes of what a previous version left behind.
    private func makeModel(configure: (UserDefaults) -> Void = { _ in }) -> (AppModel, TempDefaults) {
        let temp = TempDefaults()
        temp.defaults.set("off", forKey: "aiMode")
        temp.defaults.set("manual", forKey: "refreshInterval")
        configure(temp.defaults)
        let model = AppModel(
            prProvider: FakePRProvider(),
            secrets: InMemorySecretStore(),
            readStore: ReadStore(fileURL: tempFileURL("read-state.json")),
            verdictCache: VerdictCache(fileURL: tempFileURL("verdict-cache.json")),
            defaults: temp.defaults,
            observesSystemEvents: false
        )
        return (model, temp)
    }

    @Test func freshInstallGetsTheDefaults() {
        let (model, _) = makeModel()
        #expect(model.tabOrder == PRTab.builtin)
        #expect(model.hiddenTabs == Set(PRTab.builtin).subtracting(PRTab.defaultVisible))
        #expect(model.badgeTabs == [.reviewRequested])
    }

    @Test func savedOrderIsRestoredWithNewTabsAppendedAndAllLeading() {
        // A save from a build that predates the All tab and shipped fewer tabs.
        let (model, _) = makeModel { $0.set(["created", "assigned"], forKey: "tabOrder") }
        #expect(model.tabOrder == [.all, .created, .assigned, .reviewRequested, .mentioned, .reviewed])
    }

    @Test func duplicateAndUnknownEntriesAreDropped() {
        let (model, _) = makeModel {
            $0.set(["created", "created", "somethingFromTheFuture", "assigned"], forKey: "tabOrder")
        }
        #expect(model.tabOrder == [.all, .created, .assigned, .reviewRequested, .mentioned, .reviewed])
    }

    @Test func customTabsRestoreIntoTheSavedOrder() throws {
        let tab = CustomTab(name: "API reviews", query: "label:api review-requested:@me")
        let data = try JSONEncoder().encode([tab])
        let (model, _) = makeModel {
            $0.set(data, forKey: "customTabs")
            $0.set([PRTab.custom(tab.id).rawValue, "all"], forKey: "tabOrder")
        }
        #expect(model.customTabs == [tab])
        #expect(Array(model.tabOrder.prefix(2)) == [.custom(tab.id), .all])
        #expect(model.tabOrder.count == PRTab.builtin.count + 1)
    }

    /// A custom tab whose definition is gone (deleted, or JSON from a future
    /// build) must vanish from order, hidden, and badge sets — not crash or linger.
    @Test func deletedCustomTabDropsOutOfEveryPreference() {
        let ghost = PRTab.custom(UUID()).rawValue
        let (model, _) = makeModel {
            $0.set(["all", ghost, "created"], forKey: "tabOrder")
            $0.set([ghost], forKey: "hiddenTabs")
            $0.set([ghost], forKey: "badgeTabs")
        }
        #expect(model.tabOrder == [.all, .created, .reviewRequested, .assigned, .mentioned, .reviewed])
        #expect(model.hiddenTabs.isEmpty)
        #expect(model.badgeTabs.isEmpty, "a saved-but-empty badge list is honored, not defaulted")
    }

    @Test func customTabRawValuesRoundTrip() {
        let id = UUID()
        #expect(PRTab(rawValue: PRTab.custom(id).rawValue) == .custom(id))
        #expect(PRTab(rawValue: "custom:not-a-uuid") == nil)
        #expect(PRTab(rawValue: "reviewRequested") == .reviewRequested)
    }
}
