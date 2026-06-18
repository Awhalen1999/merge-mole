import SwiftUI

/// The dropdown panel's root. Owns the `AppModel`, lays out header → tab bar →
/// list, and kicks off the initial load. Replaces the template `ContentView`.
struct RootView: View {
    @State private var model = AppModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            TabBar(selection: $model.selectedTab, counts: model.tabCounts)
            Divider()
            content
        }
        .frame(width: 360, height: 480)
        .task { await model.load() }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.grid.2x2.fill")
                .foregroundStyle(.tint)
            Text("MergeMole")
                .font(.headline)
            Spacer()
            // AI-mode toggle lives here for now so the seam is exercisable in dev;
            // real placement is advanced settings (PLAN.md).
            Picker("AI", selection: $model.aiMode) {
                ForEach(AIMode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .controlSize(.small)
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.pullRequests.isEmpty {
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
                LazyVStack(spacing: 10) {
                    ForEach(model.visiblePullRequests) { pr in
                        PRCard(pr: pr, verdict: model.verdictState(for: pr))
                    }
                }
                .padding(12)
            }
        }
    }

    private func centered<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        VStack { Spacer(); content(); Spacer() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    RootView()
}
