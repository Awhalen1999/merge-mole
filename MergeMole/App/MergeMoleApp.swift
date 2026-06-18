import SwiftUI

@main
struct MergeMoleApp: App {
    var body: some Scene {
        // .window style gives us a real SwiftUI panel under the menu-bar icon.
        // Animated icon states (mono → amber → red) come later via NSStatusItem
        // at Step 6; the systemImage is the placeholder until then.
        MenuBarExtra("MergeMole", systemImage: "circle.grid.2x2") {
            RootView()
        }
        .menuBarExtraStyle(.window)
    }
}
