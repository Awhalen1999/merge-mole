import SwiftUI

/// The dropdown panel's root. Owns the `AppModel`, lays out header → tab bar →
/// list, and kicks off the initial load. Painted on the Flexoki paper/ink
/// background so the whole panel reads as one surface.
struct RootView: View {
    @State private var model = AppModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            TabBar(selection: $model.selectedTab, counts: model.tabCounts)
            Hairline()
            content
        }
        .frame(width: 360, height: 480)
        .background(Color.appBackground)
        .task { await model.load() }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.grid.2x2.fill")
                .foregroundStyle(Color.appAccent)
            Text("MergeMole")
                .font(.headline)
                .foregroundStyle(.appText)
            Spacer()
            // Temporary AI-mode control — moves to the Settings window at Step 3.
            Picker("AI", selection: $model.aiMode) {
                ForEach(AIMode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .controlSize(.small)
            .fixedSize()
            .tint(.appAccent)
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
            .scrollContentBackground(.hidden)
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
