import SwiftUI

/// The native Settings window (⌘,). Intentionally system-native — `Form`
/// controls + our blue accent — rather than the panel's Flexoki surface. The
/// four sections map to the plan: General / GitHub / AI / About.
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
        .frame(width: 480, height: 340)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @Environment(AppModel.self) private var model
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        @Bindable var model = model
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in LoginItem.set(on) }

            Picker("Refresh every", selection: $model.refreshMinutes) {
                Text("1 minute").tag(1)
                Text("5 minutes").tag(5)
                Text("15 minutes").tag(15)
                Text("30 minutes").tag(30)
            }
        }
        .formStyle(.grouped)
        .onAppear { launchAtLogin = LoginItem.isEnabled }
    }
}

// MARK: - GitHub

private struct GitHubSettings: View {
    @Environment(AppModel.self) private var model
    @State private var token = ""

    var body: some View {
        Form {
            Section {
                LabeledContent("Status") {
                    if model.isGitHubConnected {
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Not connected", systemImage: "circle")
                            .foregroundStyle(.secondary)
                    }
                }
                if model.isGitHubConnected {
                    Button("Disconnect", role: .destructive) {
                        model.disconnectGitHub()
                    }
                }
            }

            Section {
                SecureField("ghp_…", text: $token)
                    .font(.body.monospaced())
                Button(model.isGitHubConnected ? "Replace token" : "Save token") {
                    model.setGitHubToken(token)
                    token = ""
                }
                .disabled(token.trimmingCharacters(in: .whitespaces).isEmpty)
                Link("Create a token (scopes: repo, read:org)",
                     destination: URL(string: "https://github.com/settings/tokens/new?scopes=repo,read:org&description=MergeMole")!)
                    .font(.caption)
            } header: {
                Text("Token")
            } footer: {
                Text("Stored in your Keychain. The token is validated when PRs first load.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - AI

private struct AISettings: View {
    @Environment(AppModel.self) private var model
    @State private var apiKey = ""

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                Picker("Mode", selection: $model.aiMode) {
                    ForEach(AIMode.allCases) { Text($0.label).tag($0) }
                }
                Text(model.aiMode.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if model.aiMode == .bringYourOwn {
                Section {
                    TextField("https://api.example.com/v1  •  http://localhost:11434", text: $model.byoEndpoint)
                    SecureField("API key", text: $apiKey)
                    Button(model.byoAPIKey.isEmpty ? "Save key" : "Replace key") {
                        model.setBYOAPIKey(apiKey)
                        apiKey = ""
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Text("Endpoint")
                } footer: {
                    Text("Key is stored in your Keychain. Endpoint covers hosted models and local ones like Ollama.")
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - About

private struct AboutSettings: View {
    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(v) (\(b))"
    }

    var body: some View {
        VStack(spacing: Layout.base) {
            Image(systemName: "circle.grid.2x2.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("MergeMole")
                .font(.title2.weight(.semibold))
            Text(version)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("PR triage in your menu bar — on-device, private, free.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Link("github.com/Awhalen1999/merge-mole",
                 destination: URL(string: "https://github.com/Awhalen1999/merge-mole")!)
                .font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SettingsView()
        .environment(AppModel(secrets: InMemorySecretStore(), onboarded: true))
}
