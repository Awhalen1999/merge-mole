import SwiftUI

/// The menu-bar panel. Always three stacked layers, in this order:
///
///   1. header   — brand + controls (Refresh only when connected)
///   2. tab bar  — the relationship filter (only when there's a list to filter)
///   3. content  — exactly one state, switched from `PanelState`
///
/// Everything sits on one Flexoki surface, aligned to a single `Layout.margin`,
/// so the panel reads as one clean sheet rather than stacked components.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let state = state
        return VStack(spacing: 0) {
            PanelHeader(showsRefresh: state.showsRefresh)
            if state.showsTabs {
                TabBar(selection: $model.selectedTab,
                       tabs: model.visibleTabs,
                       counts: model.tabCounts,
                       unreadTabs: model.tabsWithUnread)
            }
            Hairline()
            content(state)
        }
        .frame(width: 400, height: 600)
        // The backdrop is user-selectable (General → Appearance): a clear fill
        // (transparent), frosted vibrancy (glass), or an opaque Flexoki surface
        // (solid). The window stays non-opaque so transparent/glass blur through;
        // a rounded clip + hairline give every mode the same panel shape.
        .background(panelFill)
        .background(PanelWindow())
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.appHairline, lineWidth: 1)
        )
        // The panel drives AI work: opening it warms the model and refreshes;
        // closing it stops feeding the model. Background fetches keep the badge
        // live, but the model only runs while you're actually looking.
        .onAppear { model.panelOpened() }
        .onDisappear { model.panelClosed() }
    }

    /// The user-selected panel backdrop.
    @ViewBuilder private var panelFill: some View {
        switch model.panelBackground {
        case .transparent: Color.clear
        case .solid:       Color.appBackground
        }
    }

    // MARK: - State

    /// The single thing the content area branches on. Computing it once keeps the
    /// layer decisions (which controls, whether tabs) and the screen choice in sync.
    private enum PanelState {
        case disconnected      // no GitHub token yet
        case loading           // first fetch, nothing to show yet
        case error(String)     // fetch failed
        case empty             // connected, but the selected tab is clear
        case list              // the PRs

        /// Refresh is pointless with no connection; otherwise it's always offered.
        var showsRefresh: Bool {
            if case .disconnected = self { false } else { true }
        }

        /// Tabs only matter when there's a list to filter or switch between.
        var showsTabs: Bool {
            switch self {
            case .loading, .empty, .list: true
            case .disconnected, .error:   false
            }
        }
    }

    private var state: PanelState {
        if !model.isGitHubConnected { return .disconnected }
        if model.isLoading && model.pullRequests.isEmpty { return .loading }
        if let error = model.loadError { return .error(error) }
        if model.visiblePullRequests.isEmpty { return .empty }
        return .list
    }

    // MARK: - Content (one screen per state)

    @ViewBuilder
    private func content(_ state: PanelState) -> some View {
        switch state {
        case .disconnected:    connectScreen
        case .loading:         SkeletonList()
        case .error(let msg):  errorScreen(msg)
        case .empty:           caughtUpScreen
        case .list:            list
        }
    }

    private var connectScreen: some View {
        StatusScreen(
            title: model.tokenRejected ? "Reconnect to GitHub" : "Connect to GitHub",
            message: model.tokenRejected
                ? "GitHub rejected your saved token — it may have expired or been revoked. Reconnect to keep triaging your pull requests."
                : "MergeMole reads your pull requests to triage what needs your attention first. Your token stays on this Mac."
        ) {
            BrandMark(size: 46)
        } actions: {
            VStack(spacing: Layout.base) {
                SettingsLink {
                    Text("Connect GitHub")
                }
                .buttonStyle(ProminentButtonStyle())
                .frame(width: 230)

                SettingsLink {
                    Text("Use a personal access token")
                }
                .buttonStyle(.plain)
                .font(.callout.weight(.medium))
                .foregroundStyle(Color.appAccent)
            }
            .padding(.top, Layout.generous)
        }
    }

    private func errorScreen(_ message: String) -> some View {
        StatusScreen(
            title: "Couldn't reach GitHub",
            message: message,
            footnote: lastSyncedFootnote
        ) {
            StatusIcon(systemName: "exclamationmark", tint: .appRed)
        } actions: {
            Button {
                Task { await model.load() }
            } label: {
                Label("Try again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(SecondaryButtonStyle())
            .padding(.top, Layout.generous)
        }
    }

    private var caughtUpScreen: some View {
        StatusScreen(
            title: "All caught up",
            message: model.selectedTab.emptyMessage
        ) {
            StatusIcon(systemName: "tray", tint: .appTextSecondary)
        } actions: {
            EmptyView()
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(model.visiblePullRequests.enumerated()), id: \.element.id) { index, pr in
                    if index > 0 { Hairline() }
                    PRCard(pr: pr, verdict: model.verdictState(for: pr))
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var lastSyncedFootnote: String? {
        guard let synced = model.lastSyncedAt else { return nil }
        return "last synced \(synced.relativeShort) ago"
    }
}

#Preview("Connected") {
    let secrets = InMemorySecretStore()
    secrets.set("preview-token", for: .githubToken)   // simulate connected
    return RootView()
        .environment(AppModel(
            prProvider: SamplePRProvider(),
            verdictEngine: SampleVerdictEngine(),   // canned verdicts (no Foundation Models in previews)
            secrets: secrets
        ))
}

#Preview("Disconnected") {
    RootView()
        .environment(AppModel(
            prProvider: SamplePRProvider(),
            verdictEngine: SampleVerdictEngine(),
            secrets: InMemorySecretStore()   // no token → connect prompt
        ))
}
