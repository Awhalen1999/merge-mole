import SwiftUI

/// The Settings window (⌘,). Reskinned to match the panel: the same Flexoki
/// paper/ink surface, `appSurface` section cards, and blue accent — so Settings
/// reads as the same app as the dropdown rather than a bare system form. Still a
/// four-tab `TabView` (General / GitHub / AI / About) for the macOS-correct shape.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            GitHubSettings()
                .tabItem { Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right") }
            AISettings()
                .tabItem { Label("AI", systemImage: "sparkles") }
            AboutSettings()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .tint(.appAccent)
        .frame(width: 500, height: 480)
    }
}

// MARK: - Shared chrome

/// A tab body: the content scrolls on the Flexoki background with even padding.
private struct SettingsScaffold<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.roomy) {
                content
            }
            .padding(Layout.roomy)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.appBackground)
    }
}

/// A titled card — the same surface + hairline as the panel's PR cards, with an
/// uppercase section label above and optional footer note below.
private struct SettingsSection<Content: View>: View {
    let title: String
    var footer: String?
    @ViewBuilder var content: Content

    init(_ title: String, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.snug) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(.appTextTertiary)

            VStack(alignment: .leading, spacing: Layout.base) {
                content
            }
            .foregroundStyle(.appText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Layout.roomy)
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: Layout.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cardRadius)
                    .strokeBorder(Color.appHairline, lineWidth: 1)
            )

            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.appTextTertiary)
                    .padding(.horizontal, Layout.tight)
            }
        }
    }
}

private extension View {
    /// Flexoki text-field chrome: inset on the panel background with a hairline.
    func flexokiField() -> some View {
        textFieldStyle(.plain)
            .padding(.horizontal, Layout.base)
            .padding(.vertical, Layout.snug)
            .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.appHairline, lineWidth: 1))
    }
}

/// A small inline status line (✓/✗ + message) shared by the connect / verify flows.
private struct InlineStatus: View {
    enum Kind { case progress(String), ok(String), error(String) }
    let kind: Kind
    var body: some View {
        HStack(spacing: Layout.snug) {
            switch kind {
            case .progress(let message):
                ProgressView().controlSize(.small)
                Text(message).foregroundStyle(.appTextSecondary)
            case .ok(let message):
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.appGreen)
                Text(message).foregroundStyle(.appTextSecondary)
            case .error(let message):
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.appRed)
                Text(message).foregroundStyle(.appTextSecondary)
            }
        }
        .font(.caption)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var confirmingReset = false

    var body: some View {
        SettingsScaffold {
            SettingsSection("Startup") {
                Toggle(isOn: $launchAtLogin) {
                    Text("Launch at login").foregroundStyle(.appText)
                }
                .onChange(of: launchAtLogin) { _, on in LoginItem.set(on) }
            }

            SettingsSection("Tabs", footer: "Choose which tabs appear in the panel. At least one stays on.") {
                ForEach(Array(PRTab.allCases.enumerated()), id: \.element) { index, tab in
                    if index > 0 { Hairline() }
                    Toggle(isOn: tabBinding(tab)) {
                        Text(tab.title).foregroundStyle(.appText)
                    }
                }
            }

            SettingsSection("Reset", footer: "Forgets your GitHub token and replays first-run setup.") {
                Button("Reset MergeMole…", role: .destructive) { confirmingReset = true }
                    .buttonStyle(.bordered)
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

    private func reset() {
        model.disconnectGitHub()
        model.resetOnboarding()
        openWindow(id: WindowID.onboarding)
    }

    private func tabBinding(_ tab: PRTab) -> Binding<Bool> {
        Binding(
            get: { model.visibleTabs.contains(tab) },
            set: { model.setTab(tab, visible: $0) }
        )
    }
}

// MARK: - GitHub

private struct GitHubSettings: View {
    @Environment(AppModel.self) private var model
    @State private var token = ""
    @State private var connecting = false
    @State private var feedback: Feedback?

    private enum Feedback { case ok(String), error(String) }

    var body: some View {
        SettingsScaffold {
            SettingsSection("Connection") {
                HStack(spacing: Layout.snug) {
                    if model.isGitHubConnected {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.appGreen)
                        Text("Connected as @\(model.currentUser)").foregroundStyle(.appText)
                    } else {
                        Image(systemName: "circle").foregroundStyle(.appTextTertiary)
                        Text("Not connected").foregroundStyle(.appTextSecondary)
                    }
                    Spacer()
                    if model.isGitHubConnected {
                        Button("Disconnect", role: .destructive) {
                            model.disconnectGitHub()
                            feedback = nil
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            SettingsSection(
                "Token",
                footer: "Verified with GitHub, then stored in your Keychain — never in plain text."
            ) {
                SecureField("ghp_…", text: $token)
                    .font(.body.monospaced())
                    .flexokiField()

                HStack(spacing: Layout.base) {
                    Button(model.isGitHubConnected ? "Replace token" : "Save token") { connect() }
                        .buttonStyle(.borderedProminent)
                        .tint(.appAccent)
                        .disabled(connecting || GitHubToken.sanitize(token).isEmpty)

                    if connecting { InlineStatus(kind: .progress("Verifying…")) }
                    else if let feedback {
                        switch feedback {
                        case .ok(let m): InlineStatus(kind: .ok(m))
                        case .error(let m): InlineStatus(kind: .error(m))
                        }
                    }
                }

                Link("Create a token (scopes: repo, read:org)",
                     destination: URL(string: "https://github.com/settings/tokens/new?scopes=repo,read:org&description=MergeMole")!)
                    .font(.caption)
            }
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

// MARK: - AI

private struct AISettings: View {
    @Environment(AppModel.self) private var model
    @State private var apiKey = ""
    @State private var verifying = false
    @State private var feedback: Feedback?

    private enum Feedback { case ok(String), error(String) }

    var body: some View {
        @Bindable var model = model
        SettingsScaffold {
            SettingsSection("Mode") {
                Picker("", selection: $model.aiMode) {
                    ForEach(AIMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text(model.aiMode.detail)
                    .font(.caption)
                    .foregroundStyle(.appTextSecondary)

                if model.onDeviceUnavailable {
                    InlineStatus(kind: .error("On-device AI isn't available on this Mac. Cards show data only."))
                }
            }

            if model.aiMode == .bringYourOwn {
                SettingsSection(
                    "Bring your own model",
                    footer: "Any OpenAI-compatible Chat Completions endpoint — hosted (OpenAI, OpenRouter…) or local (Ollama, LM Studio). The key is stored in your Keychain."
                ) {
                    labeledField("Endpoint") {
                        TextField("", text: $model.byoEndpoint,
                                  prompt: Text("https://api.openai.com/v1  •  http://localhost:11434/v1"))
                            .flexokiField()
                    }
                    labeledField("Model") {
                        TextField("", text: $model.byoModel, prompt: Text("gpt-4o-mini  •  llama3.1"))
                            .flexokiField()
                    }
                    labeledField("API key") {
                        SecureField("", text: $apiKey, prompt: Text("leave blank for local"))
                            .flexokiField()
                    }

                    HStack(spacing: Layout.base) {
                        Button("Verify connection") { verify() }
                            .buttonStyle(.borderedProminent)
                            .tint(.appAccent)
                            .disabled(verifying || !model.byoConfigured)

                        if verifying { InlineStatus(kind: .progress("Verifying…")) }
                        else if let feedback {
                            switch feedback {
                            case .ok(let m): InlineStatus(kind: .ok(m))
                            case .error(let m): InlineStatus(kind: .error(m))
                            }
                        }
                    }
                }
            }
        }
    }

    private func labeledField<Field: View>(_ label: String, @ViewBuilder _ field: () -> Field) -> some View {
        VStack(alignment: .leading, spacing: Layout.tight) {
            Text(label).font(.caption).foregroundStyle(.appTextSecondary)
            field()
        }
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
    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: Layout.base) {
            Spacer()
            Image(systemName: "circle.grid.2x2.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.appAccent)
            Text("MergeMole")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.appText)
            Text(version)
                .font(.caption)
                .foregroundStyle(.appTextSecondary)
            Text("PR triage in your menu bar — on-device, private, free.")
                .font(.callout)
                .foregroundStyle(.appTextSecondary)
                .multilineTextAlignment(.center)
            Link("github.com/Awhalen1999/merge-mole",
                 destination: URL(string: "https://github.com/Awhalen1999/merge-mole")!)
                .font(.caption)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}

#Preview {
    SettingsView()
        .environment(AppModel(secrets: InMemorySecretStore(), onboarded: true))
}
