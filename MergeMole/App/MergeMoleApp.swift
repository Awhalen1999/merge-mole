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
        .windowStyle(.hiddenTitleBar)   // traffic lights float over our own top bar
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

/// The menu-bar status item: an empty burrow when nothing's waiting, a mole rising
/// out of it (with the live count beside it) when PRs await review. Reading
/// `model.badgeCount` / `badgePriority` here ties it to the observable model, so it
/// updates after every background refresh — no manual redraw needed.
///
/// Both glyphs are template images: macOS recolors them for the menu bar on its own
/// when untinted, and the most urgent review-requested PR escalates the tint
/// mono → amber → red (`escalation`). The count rides alongside as plain text.
private struct MenuBarLabel: View {
    let model: AppModel

    var body: some View {
        let count = model.badgeCount
        HStack(spacing: 3) {
            Image(count > 0 ? "HoleMole" : "HoleEmpty")
                .renderingMode(.template)
            if count > 0 { Text("\(count)").monospacedDigit() }
        }
        .modifier(Escalation(color: escalation))
    }

    /// red = something urgent is waiting, amber = high; otherwise no tint so the
    /// plain template tracks the menu bar's own light/dark appearance.
    private var escalation: Color? {
        switch model.badgePriority {
        case .urgent: return .appRed
        case .high:   return .appAmber
        default:      return nil
        }
    }
}

/// Applies a tint only when there's an escalation; leaving it off preserves the
/// template image's automatic light/dark (and open-menu highlight) behavior.
private struct Escalation: ViewModifier {
    let color: Color?
    func body(content: Content) -> some View {
        if let color { content.foregroundStyle(color) } else { content }
    }
}
