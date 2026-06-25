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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padded ? Layout.roomy : 0)
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: Layout.cardRadius))
            .clipShape(RoundedRectangle(cornerRadius: Layout.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cardRadius)
                    .strokeBorder(Color.appHairline, lineWidth: 1)
            )
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

/// A small inline status line (✓/✗/spinner + message) shared by connect / verify.
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
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.appAmber)
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
    @State private var draggingTab: PRTab?

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
                ForEach(Array(model.orderedTabs.enumerated()), id: \.element) { index, tab in
                    if index > 0 { Hairline() }
                    TabRow(tab: tab,
                           count: model.tabCounts[tab] ?? 0,
                           isOn: tabBinding(tab),
                           dragging: $draggingTab)
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

/// One row in General → Tabs: drag grip, identity dot, title + live subtitle, and
/// a visibility checkbox. The whole row is a drag source and drop target, so
/// reordering needs no edit mode.
private struct TabRow: View {
    @Environment(AppModel.self) private var model
    let tab: PRTab
    let count: Int
    @Binding var isOn: Bool
    @Binding var dragging: PRTab?

    var body: some View {
        HStack(spacing: Layout.roomy) {
            DragGrip()
            Circle().fill(tab.dotColor).frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(tab.title).font(.callout.weight(.medium)).foregroundStyle(.appText)
                Text(tab.subtitle(count: count)).font(.caption).foregroundStyle(.appTextTertiary)
            }
            Spacer(minLength: Layout.base)
            Toggle("", isOn: $isOn).labelsHidden().toggleStyle(.checkbox)
        }
        .padding(.horizontal, Layout.roomy)
        .padding(.vertical, Layout.base + 1)
        .contentShape(Rectangle())
        .opacity(dragging == tab ? 0.35 : 1)
        .onDrag {
            dragging = tab
            return NSItemProvider(object: tab.rawValue as NSString)
        }
        .onDrop(of: [.text], delegate: TabDropDelegate(target: tab, model: model, dragging: $dragging))
    }
}

/// The six-dot reorder affordance.
private struct DragGrip: View {
    var body: some View {
        Grid(horizontalSpacing: 2.5, verticalSpacing: 2.5) {
            ForEach(0..<3, id: \.self) { _ in
                GridRow { dot; dot }
            }
        }
        .foregroundStyle(.appTextTertiary)
    }
    private var dot: some View { Circle().frame(width: 2.5, height: 2.5) }
}

/// Live reorder: as a dragged row passes over another, slot it into that place.
/// SwiftUI invokes drop callbacks on the main thread, so the model touches are
/// bridged with `assumeIsolated`.
private struct TabDropDelegate: DropDelegate {
    let target: PRTab
    let model: AppModel
    @Binding var dragging: PRTab?

    nonisolated func dropEntered(info: DropInfo) {
        MainActor.assumeIsolated {
            guard let dragging, dragging != target else { return }
            model.moveTab(dragging, to: target)
        }
    }
    nonisolated func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    nonisolated func performDrop(info: DropInfo) -> Bool {
        MainActor.assumeIsolated { dragging = nil }
        return true
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
    @State private var feedback: Feedback?
    private enum Feedback { case ok(String), error(String) }

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
        @Bindable var model = model
        VStack(alignment: .leading, spacing: Layout.snug) {
            SectionHeader(
                title: "AI Triage",
                subtitle: "Choose how MergeMole rates effort and priority. Disable it to use MergeMole as a plain PR organizer."
            )
            VStack(spacing: Layout.base) {
                ForEach(AIMode.allCases) { mode in
                    AIModeCard(mode: mode, selected: model.aiMode == mode) {
                        model.aiMode = mode
                    } expanded: {
                        if mode == .bringYourOwn { CustomModelForm() }
                    }
                }
            }
        }
    }
}

/// One AI-mode radio card. Selection shows in the filled accent radio — the card
/// border stays neutral — and the optional `expanded` content (the Custom-model
/// form) reveals beneath when selected.
private struct AIModeCard<Expanded: View>: View {
    @Environment(AppModel.self) private var model
    let mode: AIMode
    let selected: Bool
    let select: () -> Void
    @ViewBuilder var expanded: Expanded

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.roomy) {
            Button(action: select) {
                HStack(alignment: .top, spacing: Layout.roomy) {
                    Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                        .font(.title3)
                        .foregroundStyle(selected ? Color.appAccent : .appTextTertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mode.cardTitle)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.appText)
                        Text(mode.detail)
                            .font(.caption)
                            .foregroundStyle(.appTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if mode == .onDevice && model.onDeviceUnavailable {
                InlineStatus(kind: .error("On-device AI isn't available on this Mac. Cards show data only."))
            }
            if selected { expanded }
        }
        .padding(Layout.roomy)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: Layout.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cardRadius)
                .strokeBorder(Color.appHairline, lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.15), value: selected)
    }
}

/// The Custom-model form — provider preset (prefills the base URL), endpoint, key,
/// and model, plus a Verify button. Model is a free field, not a pop-up: arbitrary
/// OpenAI-compatible endpoints take any model name.
private struct CustomModelForm: View {
    @Environment(AppModel.self) private var model
    @State private var apiKey = ""
    @State private var verifying = false
    @State private var feedback: Feedback?
    private enum Feedback { case ok(String), error(String) }

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

            VStack(spacing: 2) {
                Text(version)
                    .font(.callout)
                    .foregroundStyle(.appTextSecondary)
                if let buildLine {
                    Text(buildLine)
                        .font(.caption)
                        .foregroundStyle(.appTextTertiary)
                }
            }

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

    /// The executable's build time — a real "Built …" line without a build script.
    private var buildLine: String? {
        guard let path = Bundle.main.executablePath,
              let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let date = attrs[.modificationDate] as? Date else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return "Built \(formatter.string(from: date))"
    }
}

/// A rounded brand tile standing in for the app icon.
private struct AppIconTile: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.appAccent.opacity(0.16))
            .frame(width: 76, height: 76)
            .overlay(
                Image(systemName: "circle.grid.2x2.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.appAccent)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.appHairline, lineWidth: 1)
            )
    }
}

#Preview {
    SettingsView()
        .environment(AppModel(secrets: InMemorySecretStore(), onboarded: true))
}
