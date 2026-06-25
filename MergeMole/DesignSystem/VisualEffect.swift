import SwiftUI
import AppKit

/// Makes the panel's hosting window fully transparent — non-opaque with a clear
/// background — so content floats directly over the desktop (no fill). For the
/// transient menu-bar window only; pair it with a rounded clip on the content. The
/// Solid panel mode draws an opaque Flexoki fill over this same non-opaque window.
struct PanelWindow: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true   // keep the drop shadow even with a clear/solid fill
        }
    }
}
