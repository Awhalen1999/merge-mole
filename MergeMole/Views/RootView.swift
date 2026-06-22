import SwiftUI
import AppKit

/// The dropdown panel's root. Reads the shared `AppModel` and lays out
/// header → tab bar → list. First-run onboarding is a separate window
/// (`OnboardingView`), so the panel itself is always the main panel. Painted on
/// the Flexoki paper/ink background so the whole panel reads as one surface.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        return VStack(spacing: 0) {
            header
            TabBar(selection: $model.selectedTab, tabs: model.visibleTabs, counts: model.tabCounts)
            Hairline()
            content
        }
        .frame(width: 400, height: 600)
        .background(Color.appBackground)
        .task { await model.load() }
    }

    private var header: some View {
        HStack(spacing: Layout.tight) {
            Image(systemName: "circle.grid.2x2.fill")
                .foregroundStyle(Color.appAccent)
            Text("MergeMole")
                .font(.headline)
                .foregroundStyle(.appText)
            Spacer()

            Button {
                Task { await model.load() }
            } label: {
                Label {
                    Text("Refresh")
                } icon: {
                    // Swap the arrow for a spinner while fetching, so a manual
                    // refresh visibly does something even when the list is full.
                    if model.isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .buttonStyle(HeaderButtonStyle())
            .disabled(model.isLoading)
            .help("Refresh pull requests")

            settingsMenu
        }
        .padding(.horizontal, Layout.roomy)
        .padding(.top, Layout.roomy)
    }

    /// The gear opens a small menu rather than being three separate icons: a
    /// settings entry point, About, and Quit — with the standard ⌘, / ⌘Q
    /// shortcuts surfaced right in the menu (and live whenever the panel is open).
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
            Image(systemName: "gearshape")
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(HeaderButtonStyle())
        .fixedSize()
        .help("Settings")
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if !model.isGitHubConnected {
            centered {
                ContentUnavailableView {
                    Label("Connect GitHub", systemImage: "point.3.connected.trianglepath.dotted")
                } description: {
                    Text("Add a GitHub token to see your pull requests.")
                } actions: {
                    SettingsLink { Text("Open Settings") }
                        .buttonStyle(.borderedProminent)
                        .tint(.appAccent)
                }
            }
        } else if model.isLoading && model.pullRequests.isEmpty {
            centered { ProgressView("Loading pull requests…") }
        } else if let error = model.loadError {
            centered {
                ContentUnavailableView("Couldn't load PRs", systemImage: "wifi.exclamationmark", description: Text(error))
            }
        } else if model.visiblePullRequests.isEmpty {
            centered {
                ContentUnavailableView("Nothing here", systemImage: "tray", description: Text("No pull requests in \(model.selectedTab.title)."))
            }
        } else {
            ScrollView {
                LazyVStack(spacing: Layout.roomy) {
                    ForEach(model.visiblePullRequests) { pr in
                        PRCard(pr: pr, verdict: model.verdictState(for: pr))
                    }
                }
                .padding(Layout.roomy)
            }
            .scrollContentBackground(.hidden)
        }
    }

    private func centered<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        VStack { Spacer(); content(); Spacer() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    let secrets = InMemorySecretStore()
    secrets.set("preview-token", for: .githubToken)   // simulate connected
    return RootView()
        .environment(AppModel(
            prProvider: SamplePRProvider(),
            verdictEngine: SampleVerdictEngine(),   // canned verdicts (no Foundation Models in previews)
            secrets: secrets,
            onboarded: true
        ))
}
