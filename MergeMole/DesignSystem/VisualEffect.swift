import SwiftUI
import AppKit

/// A native vibrancy backdrop — the frosted "glass" behind the menu-bar panel, the
/// same material macOS menus and Control Center ride on. Bridged from
/// `NSVisualEffectView` because SwiftUI's `Material` doesn't reliably punch through
/// a `MenuBarExtra` window to blur the desktop behind it.
///
/// Used only for the transient panel — the Settings window stays a solid system
/// surface, per macOS convention. The brand blue is never the fill here: it stays
/// reserved for accents that pop against the neutral glass.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .menu
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active   // stay frosted even when the app isn't frontmost
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
    }
}
