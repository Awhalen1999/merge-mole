import SwiftUI

@main
struct MergeMoleApp: App {
    /// One shared model for every scene — the menu-bar panel and the Settings
    /// window read and write the same state.
    @State private var model = AppModel()

    var body: some Scene {
        // .window style gives a real SwiftUI panel under the menu-bar icon.
        // Animated icon states (mono → amber → red) come later via NSStatusItem
        // at Step 7; the systemImage is the placeholder until then.
        MenuBarExtra("MergeMole", systemImage: "circle.grid.2x2") {
            RootView()
                .environment(model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}
