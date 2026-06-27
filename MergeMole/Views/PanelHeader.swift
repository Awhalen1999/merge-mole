import SwiftUI
import AppKit

/// The panel's top bar: Refresh on the left, the ⋮ menu on the right, on one fixed
/// height so it never shifts between states. Refresh appears only when there's a
/// connection to refresh; the ⋮ menu is always present — it's the only route to
/// Settings / Quit in this menu-bar agent app. The left side has room for more
/// controls as we add them.
struct PanelHeader: View {
    var showsRefresh: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: Layout.snug) {
            if showsRefresh { refreshButton }
            Spacer(minLength: Layout.base)
            settingsMenu
        }
        .padding(.horizontal, Layout.margin)
        .frame(height: Layout.headerHeight)
    }

    private var refreshButton: some View {
        Button {
            Task { await model.load() }
        } label: {
            Label {
                Text(model.isLoading ? "Refreshing…" : "Refresh")
            } icon: {
                // Swap the arrow for a spinner while fetching, so a manual refresh
                // visibly does something even when the list is already full.
                if model.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.appAccent)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .buttonStyle(HeaderButtonStyle())
        .disabled(model.isLoading)
        .help("Refresh pull requests")
    }

    /// The ⋮ opens one menu rather than a row of icons: Preferences, About, and
    /// Quit — with the standard ⌘, / ⌘Q shortcuts live whenever the panel is open.
    private var settingsMenu: some View {
        Menu {
            SettingsLink {
                Label("Preferences…", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)

            Button {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.orderFrontStandardAboutPanel(nil)
            } label: {
                Label("About MergeMole", systemImage: "info.circle")
            }

            Divider()

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit MergeMole", systemImage: "power")
            }
            .keyboardShortcut("q", modifiers: .command)
        } label: {
            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90))
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(HeaderButtonStyle(square: true))
        .fixedSize()
        .help("Settings")
    }
}
