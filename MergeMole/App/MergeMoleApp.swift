import SwiftUI
import AppKit

@main
struct MergeMoleApp: App {
    /// One shared model for every scene — the menu-bar panel and Settings both read
    /// and write the same state.
    @State private var model = AppModel()

    /// Sparkle's updater, created once and shared into Settings so the About tab drives
    /// the same instance as the background checker.
    @State private var updater = Updater()

    init() {
        // A menu-bar (LSUIElement) app has no reliable system app icon, so set it
        // explicitly at launch — this is the icon Sparkle's update dialogs and any
        // system alert display.
        if let icon = NSImage(named: "AppLogo") {
            NSApplication.shared.applicationIconImage = icon
        }
    }

    var body: some Scene {
        // .window style gives a real SwiftUI panel under the menu-bar icon.
        MenuBarExtra {
            RootView()
                .environment(model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(model)
                .environment(updater)
        }
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
