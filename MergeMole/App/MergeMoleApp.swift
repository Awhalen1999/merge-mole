import SwiftUI

enum WindowID {
    static let onboarding = "onboarding"
}

@main
struct MergeMoleApp: App {
    /// One shared model for every scene — the menu-bar panel, the onboarding
    /// window, and Settings all read and write the same state.
    @State private var model = AppModel()

    var body: some Scene {
        // .window style gives a real SwiftUI panel under the menu-bar icon.
        // Animated icon states (mono → amber → red) come later via NSStatusItem
        // at Step 7; the systemImage is the placeholder until then.
        MenuBarExtra {
            RootView()
                .environment(model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)

        // First-run onboarding as a real, standalone window. It auto-presents at
        // launch only until setup is done — read straight from UserDefaults so
        // the decision doesn't churn with observable state. (Key matches
        // AppModel's "hasCompletedOnboarding".)
        Window("Welcome to MergeMole", id: WindowID.onboarding) {
            OnboardingView()
                .environment(model)
        }
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(
            UserDefaults.standard.bool(forKey: AppModel.onboardedDefaultsKey) ? .suppressed : .presented
        )

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}

/// The menu-bar status item: the brand glyph plus a live count of PRs awaiting
/// review. Reading `model.badgeCount` here ties the badge to the observable model,
/// so it updates after every background refresh — no manual redraw needed. (The
/// richer colored-icon/badge-bubble treatment lands later via `NSStatusItem`.)
private struct MenuBarLabel: View {
    let model: AppModel
    var body: some View {
        let count = model.badgeCount
        HStack(spacing: 3) {
            Image(systemName: count > 0 ? "circle.grid.2x2.fill" : "circle.grid.2x2")
            if count > 0 { Text("\(count)") }
        }
    }
}
