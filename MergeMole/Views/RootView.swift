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
            TabBar(selection: $model.selectedTab, counts: model.tabCounts)
            Hairline()
            content
        }
        .frame(width: 360, height: 480)
        .background(Color.appBackground)
        .task { await model.load() }
    }

    private var header: some View {
        HStack(spacing: Layout.base) {
            Image(systemName: "circle.grid.2x2.fill")
                .foregroundStyle(Color.appAccent)
            Text("MergeMole")
                .font(.headline)
                .foregroundStyle(.appText)
            Spacer()

            iconButton("arrow.clockwise", help: "Refresh") {
                Task { await model.load() }
            }
            SettingsLink {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.appTextSecondary)
            .help("Settings")
            iconButton("power", help: "Quit MergeMole") {
                NSApp.terminate(nil)
            }
        }
        .padding(.horizontal, Layout.roomy)
        .padding(.top, Layout.roomy)
    }

    private func iconButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.appTextSecondary)
        .help(help)
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
