import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// The Settings window (⌘,). Three tabs — General / Providers / About — in the
/// native macOS preferences `TabView`, so the chrome (centered title + toolbar
/// tabs) is the system's. Content is Flexoki-skinned section cards on a *solid*
/// window surface — glass is for the transient panel, not a settings window. Form
/// controls stay native (segmented, pop-ups, switches, checkboxes) for the clean
/// native feel; the brand blue is the accent only, never a fill.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "slider.horizontal.3") }
            ProvidersSettings()
                .tabItem { Label("Providers", systemImage: "square.grid.2x2") }
            AboutSettings()
                .tabItem { Label("About", systemImage: "info.circle") }
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
/// lead-in above a card (or a group of cards).
private struct SectionHeader: View {
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

private extension View {
    /// Native rounded field chrome for the settings forms.
    func settingsField() -> some View { textFieldStyle(.roundedBorder) }
}

// MARK: - General

private struct GeneralSettings: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
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
            }

            SettingsSection("Startup", padded: false) {
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
            }

            SettingsSection("Tabs",
                            subtitle: "Drag to reorder. Uncheck to hide a tab from the panel.",
                            padded: false) {
                TabReorderList()
            }

            SettingsSection("Menu-bar count",
                            subtitle: "Which groups the number beside the menu-bar icon totals. Counts each PR once across the groups you pick.",
                            padded: false) {
                ForEach(Array(model.orderedTabs.enumerated()), id: \.element) { index, tab in
                    if index > 0 { Hairline() }
                    SettingsRow(label: tab.title) {
                        Toggle("", isOn: badgeBinding(for: tab))
                            .labelsHidden()
                            .toggleStyle(.checkbox)
                    }
                }
            }

            SettingsSection("Reset", subtitle: "Disconnects GitHub and replays first-run setup.") {
                Button("Reset MergeMole…", role: .destructive) { confirmingReset = true }
                    .buttonStyle(.bordered)
                    .tint(.appRed)
            }
        }
        .onAppear { launchAtLogin = LoginItem.isEnabled }
        .confirmationDialog("Reset MergeMole?", isPresented: $confirmingReset) {
            Button("Reset", role: .destructive) { reset() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This disconnects GitHub and runs onboarding again.")
        }
    }

    private func badgeBinding(for tab: PRTab) -> Binding<Bool> {
        Binding(get: { model.badgeTabs.contains(tab) },
                set: { model.setBadge(tab, on: $0) })
    }

    private func reset() {
        model.disconnectGitHub()
        model.resetOnboarding()
        openWindow(id: WindowID.onboarding)
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
            HStack(spacing: Layout.snug) {
                Image(systemName: "circle").foregroundStyle(.appTextTertiary)
                Text("Not connected").foregroundStyle(.appTextSecondary)
            }
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
                subtitle: "Choose how MergeMole rates priority. Disable it to use MergeMole as a plain PR organizer."
            )
            VStack(spacing: Layout.base) {
                ForEach(AIMode.allCases) { mode in
                    RadioCard(title: mode.cardTitle,
                              detail: mode.detail,
                              selected: model.aiMode == mode) {
                        model.aiMode = mode
                    }
                    // On-device flags when it can't run here; "bring your own"
                    // reveals its endpoint form in a card just below.
                    if mode == .onDevice && model.onDeviceUnavailable {
                        InlineStatus(kind: .error("On-device AI isn't available on this Mac. Cards show data only."))
                    }
                    if mode == .bringYourOwn && model.aiMode == .bringYourOwn {
                        CustomModelForm().cardSurface()
                    }
                }
            }
            .animation(.easeOut(duration: 0.15), value: model.aiMode)
        }
    }
}

/// The Custom-model form — provider preset (prefills the base URL), endpoint, key,
/// and model, plus a Verify button. Model is a free field, not a pop-up: arbitrary
/// OpenAI-compatible endpoints take any model name.
private struct CustomModelForm: View {
    @Environment(AppModel.self) private var model
    @State private var apiKey = ""
    @State private var verifying = false
    @State private var feedback: InlineFeedback?

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: Layout.roomy) {
            Grid(alignment: .leading, horizontalSpacing: Layout.roomy, verticalSpacing: Layout.base) {
                GridRow {
                    fieldLabel("Provider")
                    Picker("", selection: $model.byoProvider) {
                        ForEach(BYOProvider.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: model.byoProvider) { _, _ in model.applyProviderPreset() }
                }
                GridRow {
                    fieldLabel("Base URL")
                    TextField("", text: $model.byoEndpoint, prompt: Text("https://api.openai.com/v1"))
                        .settingsField()
                }
                GridRow {
                    fieldLabel("API key")
                    SecureField("", text: $apiKey,
                                prompt: Text(model.hasBYOKey ? "•••••• stored — leave blank to keep" : "leave blank for local"))
                        .settingsField()
                }
                GridRow {
                    fieldLabel("Model")
                    TextField("", text: $model.byoModel, prompt: Text(model.byoProvider.modelPlaceholder))
                        .settingsField()
                }
            }

            HStack(spacing: Layout.base) {
                Button("Verify connection") { verify() }
                    .buttonStyle(.borderedProminent)
                    .tint(.appAccent)
                    .disabled(verifying || !model.byoConfigured)
                if verifying { InlineStatus(kind: .progress("Verifying…")) }
                else if let feedback {
                    switch feedback {
                    case .ok(let m):    InlineStatus(kind: .ok(m))
                    case .error(let m): InlineStatus(kind: .error(m))
                    }
                }
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.appTextSecondary)
            .gridColumnAlignment(.leading)
    }

    private func verify() {
        Task {
            if !apiKey.isEmpty {
                model.setBYOAPIKey(apiKey)
                apiKey = ""
            }
            verifying = true
            feedback = nil
            if let error = await model.testRemoteModel() {
                feedback = .error(error)
            } else {
                feedback = .ok("Connected to \(model.byoModel)")
                await model.refreshVerdicts()
            }
            verifying = false
        }
    }
}

// MARK: - About

private struct AboutSettings: View {
    @AppStorage("checkForUpdatesAutomatically") private var autoUpdate = true

    // Edit these in one place. Website is a placeholder until the marketing page is up.
    private let repoURL = URL(string: "https://github.com/Awhalen1999/merge-mole")!
    private let websiteURL = URL(string: "https://mergemole.app")!

    var body: some View {
        VStack(spacing: Layout.base) {
            Spacer()

            AppIconTile()

            Text("MergeMole")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.appText)

            Text(version)
                .font(.callout)
                .foregroundStyle(.appTextSecondary)

            Text("Surface the pull requests that actually need you.")
                .font(.callout)
                .foregroundStyle(.appTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, Layout.tight)

            HStack(spacing: Layout.generous) {
                Link(destination: repoURL) {
                    Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Link(destination: websiteURL) {
                    Label("Website", systemImage: "globe")
                }
            }
            .font(.callout)
            .tint(.appAccent)
            .padding(.top, Layout.snug)

            Divider()
                .frame(width: 200)
                .padding(.vertical, Layout.roomy)

            Toggle("Check for updates automatically", isOn: $autoUpdate)
                .toggleStyle(.checkbox)

            Button("Check for Updates…") {
                NSWorkspace.shared.open(repoURL.appendingPathComponent("releases"))
            }
            .buttonStyle(.bordered)

            Spacer()

            Text("© 2026 MergeMole · MIT License")
                .font(.caption2)
                .foregroundStyle(.appTextTertiary)
                .padding(.bottom, Layout.base)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Layout.roomy)
        .background(Color.appBackground)
    }

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(short) (\(build))"
    }
}

#Preview {
    SettingsView()
        .environment(AppModel(secrets: InMemorySecretStore(), onboarded: true))
}
