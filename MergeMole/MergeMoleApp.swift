import SwiftUI

@main
struct MergeMoleApp: App {
    var body: some Scene {
        MenuBarExtra("MergeMole", systemImage: "circle.grid.2x2") {
            ContentView()
                .frame(width: 360, height: 420)
        }
        .menuBarExtraStyle(.window)
    }
}
