import SwiftUI

@main
struct MergeMoleApp: App {
    /// One shared model for every scene — the menu-bar panel and Settings both read
    /// and write the same state.
    @State private var model: AppModel

    /// Sparkle's updater, created once and shared into Settings so the About tab drives
    /// the same instance as the background checker.
    @State private var updater: Updater

    init() {
        // Unit tests launch this app as their host process. A live model there would
        // read the real Keychain, fetch GitHub, and schedule refreshes mid-suite —
        // and Sparkle would launch its scheduled checker. Hand the scenes an inert,
        // sample-backed stand-in instead; the tests build their own models.
        if ProcessInfo.processInfo.isTestRun {
            _model = State(initialValue: Self.inertTestHostModel())
            _updater = State(initialValue: Updater(startsUpdater: false))
        } else {
            _model = State(initialValue: AppModel())
            _updater = State(initialValue: Updater())
        }
    }

    /// A model with every dependency faked and onboarding pre-completed, so the
    /// hosted scenes render without side effects (and without the setup window).
    private static func inertTestHostModel() -> AppModel {
        let suiteName = "app.mergemole.test-host"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(true, forKey: "onboardingCompleted")
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("mergemole-test-host", isDirectory: true)
        try? FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        return AppModel(
            prProvider: SamplePRProvider(),
            secrets: InMemorySecretStore(),
            readStore: ReadStore(fileURL: scratch.appendingPathComponent("read-state.json")),
            verdictCache: VerdictCache(fileURL: scratch.appendingPathComponent("verdict-cache.json")),
            defaults: defaults,
            observesSystemEvents: false
        )
    }

    var body: some Scene {
        // .window style gives a real SwiftUI panel under the menu-bar icon.
        MenuBarExtra {
            RootView()
                .environment(model)
                .environment(updater)   // the panel's ⋮ menu offers Check for Updates
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(model)
                .environment(updater)
        }

        // First-run setup. The scene itself carries the policy: it presents at
        // launch only until onboarding has completed (finished, skipped, or a
        // GitHub token predating the wizard — see `hasCompletedOnboarding`), and
        // nothing ever opens it programmatically, so it can't reappear.
        Window("MergeMole Setup", id: OnboardingView.windowID) {
            OnboardingView()
                .environment(model)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(model.hasCompletedOnboarding ? .suppressed : .presented)
        .restorationBehavior(.disabled)
    }
}

extension ProcessInfo {
    /// Whether a test runner is hosting this process. Checked at app init so the
    /// host stays inert during suite runs; covers both the XCTest environment
    /// markers and the runtime-injected XCTest framework (Swift Testing runs
    /// inside the same unified runner).
    var isTestRun: Bool {
        environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
            || environment["XCTestBundlePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }
}

/// The menu-bar status item: an empty burrow when nothing's waiting, a mole rising
/// out of it (with the live count beside it) when PRs await review. Reading
/// `model.badgeCount` ties it to the observable model, so it refreshes after every
/// background fetch with no manual redraw. Both glyphs are template images, so
/// macOS keeps them monochrome and adapts them to the menu bar — color can't apply
/// here (the priority tint lives in the panel header, where it can).
private struct MenuBarLabel: View {
    let model: AppModel

    var body: some View {
        let count = model.badgeCount
        HStack(spacing: 3) {
            Image(count > 0 ? "HoleMole" : "HoleEmpty")
                .renderingMode(.template)
            if count > 0 { Text("\(count)").monospacedDigit() }
        }
        // The label renders at launch (the panel content is lazy), so this gives us a
        // live count before the panel is ever opened. `loadIfStale` no-ops when
        // disconnected or recently synced, so it won't double-fetch on first open.
        .task { await model.loadIfStale() }
    }
}
