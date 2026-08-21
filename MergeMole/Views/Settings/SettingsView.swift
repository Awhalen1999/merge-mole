import SwiftUI

/// The Settings window (⌘,). Five tabs — General / Tabs / Notifications /
/// Providers / About — in the native macOS preferences `TabView`, so the chrome (centered
/// title + toolbar tabs) is the system's. Content is Flexoki-skinned section
/// cards on a *solid* window surface — glass is for the transient panel, not a
/// settings window. Form controls stay native (segmented, pop-ups, switches,
/// checkboxes) for the clean native feel; the brand blue is the accent only,
/// never a fill.
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.settingsTab) {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "slider.horizontal.3") }
                .tag(SettingsTab.general)
            TabsSettings()
                .tabItem { Label("Tabs", systemImage: "rectangle.3.group") }
                .tag(SettingsTab.tabs)
            UnreadSettings()
                .tabItem { Label("Notifications", systemImage: "app.badge") }
                .tag(SettingsTab.unread)
            ProvidersSettings()
                .tabItem { Label("Providers", systemImage: "square.grid.2x2") }
                .tag(SettingsTab.providers)
            AboutSettings()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .tint(.appAccent)
        .frame(width: 560, height: 560)
    }
}

// MARK: - Shared chrome

/// A tab body: content scrolls on the solid Flexoki window surface with even padding.
private struct SettingsScaffold<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.generous) {
                content
            }
            .padding(Layout.generous)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.appBackground)
    }
}

/// An uppercase section label with an optional one-line description beneath — the
/// lead-in above a card (or a group of cards). Shared with the sheets that grow
/// out of this window (the custom-tab editor), so their sections match.
struct SectionHeader: View {
    let title: String
    var subtitle: String?
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tight) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(.appTextTertiary)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.appTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// The titled surface card. `padded` adds the standard inner inset; pass `false`
/// for row lists that manage their own padding so the dividers run edge-to-edge.
private struct SettingsSection<Content: View>: View {
    let title: String
    var subtitle: String?
    var padded = true
    @ViewBuilder var content: Content

    init(_ title: String, subtitle: String? = nil, padded: Bool = true, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.padded = padded
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.snug) {
            SectionHeader(title: title, subtitle: subtitle)
            VStack(alignment: .leading, spacing: padded ? Layout.base : 0) {
                content
            }
            .cardSurface(padded: padded)
        }
    }
}

/// A label-left / control-right row for inside an unpadded section card.
private struct SettingsRow<Trailing: View>: View {
    let label: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Layout.roomy) {
            Text(label).foregroundStyle(.appText)
            Spacer(minLength: Layout.base)
            trailing
        }
        .padding(.horizontal, Layout.roomy)
        .padding(.vertical, Layout.base + 2)
    }
}

extension View {
    /// Native rounded field chrome for the settings forms (and their sheets).
    func settingsField() -> some View { textFieldStyle(.roundedBorder) }
}

/// A form field's leading label — one look for every settings form.
struct FieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.appTextSecondary)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @Environment(AppModel.self) private var model
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var confirmingReset = false

    var body: some View {
        @Bindable var model = model
        SettingsScaffold {
            SettingsSection("Appearance", padded: false) {
                SettingsRow(label: "Panel background") {
                    Picker("", selection: $model.panelBackground) {
                        ForEach(PanelBackground.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                Hairline()
                SettingsRow(label: "Layout") {
                    Picker("", selection: $model.cardLayout) {
                        ForEach(CardLayout.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                Hairline()
                SettingsRow(label: "Detail") {
                    Picker("", selection: $model.cardDetail) {
                        ForEach(CardDetail.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
            }

            SettingsSection("Behavior", padded: false) {
                SettingsRow(label: "Launch MergeMole at login") {
                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(.appAccent)
                        .onChange(of: launchAtLogin) { _, on in LoginItem.set(on) }
                }
                Hairline()
                SettingsRow(label: "Refresh automatically") {
                    Picker("", selection: $model.refreshInterval) {
                        ForEach(RefreshInterval.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                Hairline()
                SettingsRow(label: "Include PRs for archived repositories") {
                    Toggle("", isOn: $model.includeArchivedRepos)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(.appAccent)
                }
            }

            SettingsSection("Reset", subtitle: "Erases all local data: keys, connections, and preferences. MergeMole returns to a clean state.") {
                Button("Reset MergeMole…", role: .destructive) { confirmingReset = true }
                    .buttonStyle(.bordered)
                    .tint(.appRed)
            }
        }
        .onAppear { launchAtLogin = LoginItem.isEnabled }
        .confirmationDialog("Reset MergeMole?", isPresented: $confirmingReset) {
            // Settings stays open on purpose: watching every control snap to
            // defaults is the confirmation the reset worked, and the reconnect
            // path is right here.
            Button("Erase everything", role: .destructive) { model.resetAll() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This erases your GitHub connection, saved model keys, and all preferences from this Mac. The panel returns to its connect screen.")
        }
    }
}

// MARK: - Tabs

/// The panel's tab structure: which tabs show and in what order, plus the user's
/// own custom tabs — created and edited in a sheet, then living in the same list
/// as the built-ins. (Which groups feed the menu-bar count lives on the Unread
/// tab, with the rest of the unread system.)
private struct TabsSettings: View {
    @Environment(AppModel.self) private var model
    /// The custom-tab sheet, when open — creating a new tab or editing an existing one.
    @State private var editing: CustomTabEditor.Mode?

    var body: some View {
        SettingsScaffold {
            SettingsSection("Your tabs",
                            subtitle: "Drag to reorder. Uncheck to hide. Add custom tabs from GitHub searches, scoped to a repo, an organization, or anything else you can query.",
                            padded: false) {
                TabReorderList { editing = .edit($0) }
                Hairline()
                NewTabRow { editing = .create }
            }
        }
        .sheet(item: $editing) { mode in
            CustomTabEditor(mode: mode)
        }
    }
}

// MARK: - Unread

/// The unread system, top to bottom: what flags a PR (the mode), when a read PR
/// flags again (the activity signals), and where the count surfaces (which groups
/// feed the menu-bar badge). One tab because it's one mental model — "why is the
/// menu bar showing 3?" should have a single answer screen.
private struct UnreadSettings: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var model = model
        SettingsScaffold {
            SettingsSection("Notifications",
                            subtitle: "Sent when a PR in your watched tabs turns unread.",
                            padded: false) {
                SettingsRow(label: "Send me notifications") {
                    Toggle("", isOn: $model.notificationsEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(.appAccent)
                }
                // Delivery has exactly one invisible failure: permission denied,
                // where the app works and banners silently never appear. Surface
                // it right where the user just asked for them.
                if model.notificationsEnabled && model.notificationsBlocked {
                    Hairline()
                    HStack(spacing: Layout.base) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.appAmber)
                        Text("macOS is blocking MergeMole notifications.")
                            .foregroundStyle(.appText)
                        Spacer(minLength: Layout.base)
                        Button("Open System Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                                openURL(url)
                            }
                        }
                        .buttonStyle(.link)
                    }
                    .padding(.horizontal, Layout.roomy)
                    .padding(.vertical, Layout.base + 2)
                }
            }

            SettingsSection("Activity", subtitle: "The activity that flags a PR as unread.", padded: false) {
                SettingsRow(label: "Flag") {
                    Picker("", selection: $model.unreadMode) {
                        ForEach(UnreadMode.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                // The selected mode keeps its one-line explanation, same as the
                // onboarding step, so the segmented control never reads cryptic.
                Text(model.unreadMode.detail)
                    .font(.caption)
                    .foregroundStyle(.appTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Layout.roomy)
                    .padding(.bottom, Layout.base + 2)
                // The activity signals define the right segment; the card grows to
                // show them and collapses back to the mode row for New-only
                // (the checkbox config is kept either way).
                if model.unreadMode == .activity {
                    Group {
                        Hairline()
                        UnreadSignalList()
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.15), value: model.unreadMode)

            SettingsSection("Watched tabs",
                            subtitle: "The tabs you're notified about for new activity. These also feed the menu-bar count, each PR counted once.",
                            padded: false) {
                BadgeTabList()
            }
        }
        // On appear and again whenever the toggle flips: enabling notifications
        // against a denied permission should show the warning immediately.
        .task(id: model.notificationsEnabled) { await model.refreshNotificationPermission() }
    }
}

// MARK: - Providers

private struct ProvidersSettings: View {
    var body: some View {
        SettingsScaffold {
            SettingsSection("GitHub") {
                GitHubConnectionCard()
            }
            AITriageSection()
        }
    }
}

private struct GitHubConnectionCard: View {
    @Environment(AppModel.self) private var model
    @State private var token = ""
    @State private var connecting = false
    @State private var feedback: InlineFeedback?

    var body: some View {
        if model.isGitHubConnected { connected } else { disconnected }
    }

    private var connected: some View {
        HStack(spacing: Layout.roomy) {
            Avatar(url: model.currentUserAvatarURL, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Layout.snug) {
                    Text("@\(model.currentUser)")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.appText)
                    StatusItem(marker: .dot, text: "Connected", tint: .appGreen)
                }
                Text("Personal access token · repo, read:org")
                    .font(.caption.monospaced())
                    .foregroundStyle(.appTextSecondary)
            }
            Spacer(minLength: Layout.base)
            Button("Disconnect", role: .destructive) {
                model.disconnectGitHub()
                feedback = nil
            }
            .buttonStyle(.bordered)
            .tint(.appRed)
        }
    }

    private var disconnected: some View {
        VStack(alignment: .leading, spacing: Layout.base) {
            StatusItem(marker: .ring, text: "Not connected", tint: .appTextTertiary)
            SecureField("ghp_…", text: $token)
                .font(.body.monospaced())
                .settingsField()
            HStack(spacing: Layout.base) {
                Button("Save token") { connect() }
                    .buttonStyle(.borderedProminent)
                    .tint(.appAccent)
                    .disabled(connecting || GitHubToken.sanitize(token).isEmpty)
                if connecting { InlineStatus(kind: .progress("Verifying…")) }
                else if let feedback {
                    switch feedback {
                    case .ok(let m):    InlineStatus(kind: .ok(m))
                    case .error(let m): InlineStatus(kind: .error(m))
                    }
                }
            }
            Link("Create a token (scopes: repo, read:org)",
                 destination: URL(string: "https://github.com/settings/tokens/new?scopes=repo,read:org&description=MergeMole")!)
                .font(.caption)
        }
    }

    private func connect() {
        Task {
            connecting = true
            feedback = nil
            switch await model.connect(rawToken: token) {
            case .connected(let login):
                feedback = .ok("Connected as @\(login)")
                token = ""
            case .failed(let message):
                feedback = .error(message)
            }
            connecting = false
        }
    }
}

private struct AITriageSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.snug) {
            SectionHeader(
                title: "AI Triage",
                subtitle: "AI gives every PR a one-line summary, an effort rating, and a priority. Disable it to use MergeMole as a plain PR organizer."
            )
            VStack(spacing: Layout.base) {
                ForEach(AIMode.allCases) { mode in
                    // On-device shows why it can't run inside its own card;
                    // "bring your own" grows its card to hold the endpoint form.
                    if mode == .bringYourOwn {
                        RadioCard(title: mode.cardTitle,
                                  detail: mode.detail,
                                  selected: model.aiMode == mode) {
                            model.aiMode = mode
                        } expansion: {
                            CustomModelForm().padding(Layout.roomy)
                        }
                    } else {
                        RadioCard(title: mode.cardTitle,
                                  detail: mode.detail,
                                  warning: mode == .onDevice ? model.onDeviceUnavailableReason : nil,
                                  selected: model.aiMode == mode) {
                            model.aiMode = mode
                        }
                    }
                }
            }
            .animation(.easeOut(duration: 0.15), value: model.aiMode)
        }
    }
}

/// The Custom-model form. A single connection (one key + one model); switching
/// provider clears it after a confirmation. Flow:
///   1. Pick a provider (Base URL is shown only for the open-ended "compatible" case).
///   2. Enter the API key and press **Connect** — saves the key and fetches the
///      endpoint's model list. Nothing happens automatically while you type.
///   3. The Model picker unlocks once connected; choose a model, then **Test
///      connection** to confirm it actually answers.
struct CustomModelForm: View {
    @Environment(AppModel.self) private var model
    @State private var apiKey = ""
    /// A provider the user picked that needs a "this will disconnect you" confirm.
    @State private var pendingProvider: BYOProvider?

    private var isConnecting: Bool {
        if case .loading = model.modelDiscovery { return true }
        return false
    }
    private var isConnected: Bool {
        if case .loaded = model.modelDiscovery { return true }
        return false
    }
    private var isTesting: Bool {
        if case .testing = model.byoStatus { return true }
        return false
    }

    /// Connect needs an endpoint, plus a key for the hosted providers (local
    /// endpoints authenticate with none).
    private var canConnect: Bool {
        guard !model.byoEndpoint.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if model.byoProvider == .compatible { return true }
        return !apiKey.isEmpty || model.hasBYOKey
    }

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: Layout.roomy) {
            connectionHeader

            Grid(alignment: .leading, horizontalSpacing: Layout.roomy, verticalSpacing: Layout.base) {
                GridRow {
                    fieldLabel("Provider")
                    Picker("", selection: providerSelection) {
                        ForEach(BYOProvider.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Base URL is only the user's to set for a generic OpenAI-compatible
                // endpoint. For OpenAI and Anthropic it's fixed by the preset, so we
                // hide it rather than show an editable field nobody should touch.
                if model.byoProvider == .compatible {
                    GridRow {
                        fieldLabel("Base URL")
                        TextField("", text: $model.byoEndpoint,
                                  prompt: Text("http://localhost:11434/v1  (Ollama)"))
                            .settingsField()
                    }
                }

                GridRow {
                    fieldLabel("API key")
                    HStack(spacing: Layout.snug) {
                        SecureField("", text: $apiKey, prompt: Text(keyPrompt))
                            .settingsField()
                            .onSubmit { if canConnect && !isConnecting { connect() } }
                            // Editing the key invalidates the fetched list — re-lock
                            // the model picker until the user reconnects.
                            .onChange(of: apiKey) { _, _ in model.resetBYOConnection() }
                        Button(isConnected ? "Reconnect" : "Connect") { connect() }
                            .buttonStyle(.bordered)
                            .tint(.appAccent)
                            .disabled(!canConnect || isConnecting)
                            .fixedSize()
                    }
                }

                GridRow {
                    fieldLabel("Model")
                        .gridColumnAlignment(.leading)
                    ModelPickerField()
                }
            }

            connectStatus

            HStack(spacing: Layout.base) {
                Button("Test connection") { test() }
                    .buttonStyle(.borderedProminent)
                    .tint(.appAccent)
                    .disabled(isTesting || !model.byoConfigured)
                testStatus
                Spacer(minLength: Layout.base)
                if model.hasBYOKey || !model.byoModel.isEmpty {
                    Button("Disconnect") { disconnect() }
                        .buttonStyle(.borderless)
                        .tint(.appRed)
                        .help("Forget the saved key and model")
                }
            }
        }
        .confirmationDialog(
            "Switch provider?",
            isPresented: Binding(get: { pendingProvider != nil },
                                 set: { if !$0 { pendingProvider = nil } }),
            presenting: pendingProvider
        ) { provider in
            Button("Switch & disconnect", role: .destructive) {
                model.switchProvider(to: provider)
                apiKey = ""
                pendingProvider = nil
            }
            Button("Cancel", role: .cancel) { pendingProvider = nil }
        } message: { provider in
            Text("Switching to \(provider.label) disconnects you from \(connectedSummary) and clears the saved key.")
        }
    }

    /// Persistent "are we wired up?" line at the top of the form.
    @ViewBuilder private var connectionHeader: some View {
        if model.byoReady {
            StatusItem(marker: .dot,
                       text: "Connected · \(model.byoProvider.label) · \(model.byoModel)",
                       tint: .appGreen)
        } else {
            StatusItem(marker: .ring, text: "Not connected", tint: .appTextTertiary)
        }
    }

    /// Provider-picker binding that intercepts a change when there's a connection to
    /// lose, routing it through the confirmation first.
    private var providerSelection: Binding<BYOProvider> {
        Binding(
            get: { model.byoProvider },
            set: { newValue in
                guard newValue != model.byoProvider else { return }
                if model.hasBYOKey || !model.byoModel.isEmpty {
                    pendingProvider = newValue
                } else {
                    model.switchProvider(to: newValue)
                    apiKey = ""
                }
            }
        )
    }

    private var connectedSummary: String {
        model.byoModel.isEmpty
            ? "your current model"
            : "\(model.byoProvider.label) · \(model.byoModel)"
    }

    /// Result of step 2 (Connect): connecting / connected + model count / failure.
    @ViewBuilder private var connectStatus: some View {
        switch model.modelDiscovery {
        case .idle:
            EmptyView()
        case .loading:
            InlineStatus(kind: .progress("Connecting…"))
        case .loaded(let models):
            InlineStatus(kind: .ok(models.isEmpty
                ? "Connected, but the endpoint listed no models. Type one below."
                : "Connected: \(models.count) models available. Choose one below."))
        case .failed(let message):
            InlineStatus(kind: .error(message))
        }
    }

    /// Result of step 3 (Test connection).
    @ViewBuilder private var testStatus: some View {
        switch model.byoStatus {
        case .untested:        EmptyView()
        case .testing:         InlineStatus(kind: .progress("Testing…"))
        case .ok(let m):       InlineStatus(kind: .ok("Ready, triaging with \(m)"))
        case .failed(let m):   InlineStatus(kind: .error(m))
        }
    }

    /// Required for the hosted providers, optional for a local endpoint.
    private var keyPrompt: String {
        if model.hasBYOKey { return "•••••• saved. Press Connect to reuse it" }
        return model.byoProvider == .compatible
            ? "Optional: leave blank for local models"
            : "Paste your API key, then Connect"
    }

    private func fieldLabel(_ text: String) -> some View {
        FieldLabel(text).gridColumnAlignment(.leading)
    }

    /// Save the typed key (if any), then fetch the endpoint's model list.
    private func connect() {
        Task {
            if !apiKey.isEmpty { model.setBYOAPIKey(apiKey) }
            await model.discoverModels()
        }
    }

    /// Confirm the chosen model actually answers, and re-triage on success.
    private func test() {
        Task { await model.verifyBYO() }
    }

    /// Forget the saved key + model.
    private func disconnect() {
        apiKey = ""
        model.clearBYOConnection()
    }
}

/// The Model row: a text field paired with a ▾ menu of the models Connect fetched.
/// Locked until the endpoint is connected (or a model is already saved from a prior
/// session), so the flow reads top-to-bottom: connect, then choose.
private struct ModelPickerField: View {
    @Environment(AppModel.self) private var model

    private var models: [String] {
        if case .loaded(let m) = model.modelDiscovery { return m }
        return []
    }
    private var isConnected: Bool {
        if case .loaded = model.modelDiscovery { return true }
        return false
    }
    /// Editable once connected, or when a model is already configured (returning user).
    private var isEnabled: Bool {
        isConnected || !model.byoModel.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        @Bindable var model = model
        HStack(spacing: Layout.snug) {
            TextField("", text: $model.byoModel,
                      prompt: Text(isConnected ? "Choose a model" : "Connect first to load models"))
                .settingsField()
                .disabled(!isEnabled)
            Menu {
                if models.isEmpty {
                    Text("No models, connect first")
                } else {
                    ForEach(models, id: \.self) { id in
                        Button(id) { model.byoModel = id }
                    }
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(models.isEmpty)
            .help("Choose from the models this endpoint offers")
        }
    }
}

// MARK: - About

private struct AboutSettings: View {
    @Environment(Updater.self) private var updater

    // Edit these in one place. Website is a placeholder until the marketing page is up.
    private let repoURL = URL(string: "https://github.com/Awhalen1999/merge-mole")!
    private let websiteURL = URL(string: "https://mergemole.app")!
    private let releasesURL = URL(string: "https://mergemole.app/changelog")!

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            identity
            links
            updates
            Spacer()
            Text("© 2026 MergeMole · MIT License")
                .font(.caption2)
                .foregroundStyle(.appTextTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .multilineTextAlignment(.center)
        .padding(Layout.generous)
        .background(Color.appBackground)
    }

    /// Icon, name, version + build date, tagline — the centered identity block.
    private var identity: some View {
        VStack(spacing: Layout.base) {
            // The app-icon artwork, loaded straight from the asset catalog — not via
            // NSApplicationIcon, which is an unreliable LaunchServices lookup for a
            // menu-bar accessory app. This shows the real mark in every context.
            Image("AppLogo")
                .resizable()
                .frame(width: 72, height: 72)
                .clipShape(.rect(cornerRadius: 16, style: .continuous))
            VStack(spacing: Layout.tight) {
                Text("MergeMole")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.appText)
                Text(version)
                    .font(.callout)
                    .foregroundStyle(.appTextSecondary)
                if let buildDate {
                    Text("Built \(buildDate)")
                        .font(.caption)
                        .foregroundStyle(.appTextTertiary)
                }
            }
            Text("Your pull requests, triaged by AI, in your menu bar")
                .font(.callout)
                .foregroundStyle(.appTextSecondary)
        }
    }

    /// External links, stacked and centered.
    private var links: some View {
        VStack(spacing: Layout.roomy) {
            Link(destination: repoURL) {
                Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            Link(destination: websiteURL) {
                Label("Website", systemImage: "globe")
            }
            Link(destination: releasesURL) {
                Label("What's New", systemImage: "sparkles")
            }
        }
        .font(.callout)
        .tint(.appAccent)
        .padding(.top, Layout.generous)
    }

    /// Update controls — in the centered flow, not pinned to the bottom. Both the
    /// toggle and the button drive Sparkle directly (see `Updater`). No release
    /// channel yet: the app isn't mature enough to split stable/beta tracks.
    private var updates: some View {
        VStack(spacing: Layout.roomy) {
            Toggle("Check for updates automatically", isOn: Binding(
                get: { updater.automaticallyChecksForUpdates },
                set: { updater.setAutomaticChecks($0) }
            ))
            .toggleStyle(.checkbox)
            Button("Check for Updates…") { updater.checkForUpdates() }
                .buttonStyle(.bordered)
                // Neutral text — the window-level accent tint would otherwise make this
                // a loud blue; a check-for-updates button is secondary, not primary.
                .tint(.appText)
                // Sparkle can't run two checks at once; mirror its readiness.
                .disabled(!updater.canCheckForUpdates)
        }
        .padding(.top, Layout.generous)
    }

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    /// When the app was last built, from the executable's modification date — the
    /// closest stand-in for a build timestamp without baking one in at compile time.
    private var buildDate: String? {
        guard let url = Bundle.main.executableURL,
              let date = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
        else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    SettingsView()
        .environment(AppModel(secrets: InMemorySecretStore()))
        .environment(Updater())
}
