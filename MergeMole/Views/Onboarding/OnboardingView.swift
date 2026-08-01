import SwiftUI
import AppKit

/// The first-run setup wizard: welcome → connect GitHub → choose AI → personalize
/// → done, in its own window (see the scene in `MergeMoleApp`). Every step edits
/// the live `AppModel` directly, exactly like Settings does — there's nothing to
/// apply or roll back, so Back and Skip need no bookkeeping. Finishing (or
/// skipping) records completion and closes the window; the panel takes it from
/// there.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismissWindow) private var dismissWindow

    static let windowID = "onboarding"

    /// The five steps, in order. Raw values give Back/Continue for free.
    private enum Step: Int, CaseIterable {
        case welcome, connect, triage, personalize, done

        var next: Step { Step(rawValue: rawValue + 1) ?? self }
        var previous: Step { Step(rawValue: rawValue - 1) ?? self }
    }

    @State private var step: Step = .welcome

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Hairline()
                footer
            }
            // Skip is always available until the last step, where Done takes over.
            if step != .done {
                Button("Skip setup") { finish() }
                    .buttonStyle(QuietButtonStyle())
                    .font(.callout.weight(.medium))
                    .padding(Layout.roomy)
            }
        }
        .frame(width: 620, height: 700)
        .background(Color.appBackground)
        // An accessory (menu-bar) app doesn't come forward on its own — without
        // this the wizard can open behind whatever the user was doing.
        .onAppear { NSApp.activate(ignoringOtherApps: true) }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .welcome:     WelcomeStep()
        case .connect:     ConnectStep()
        case .triage:      TriageStep()
        case .personalize: PersonalizeStep()
        case .done:        DoneStep()
        }
    }

    /// Mark setup done and close the window — shared by Skip and the final Done.
    private func finish() {
        model.completeOnboarding()
        dismissWindow(id: Self.windowID)
    }

    // MARK: Footer

    /// Back on the left, the step's primary action on the right, progress dots
    /// centered as an overlay so they never shift as the buttons change.
    private var footer: some View {
        HStack {
            if step != .welcome {
                Button("Back") { step = step.previous }
                    .buttonStyle(QuietButtonStyle())
                    .font(.callout.weight(.medium))
            }
            Spacer()
            primaryAction
        }
        .overlay(dots)
        .padding(.horizontal, Layout.generous)
        .frame(height: 64)
        .background(Color.appSurface)
    }

    @ViewBuilder private var primaryAction: some View {
        switch step {
        case .welcome:
            prominent("Get Started")
        case .connect:
            // Connecting is the step's own affordance; the footer only moves on.
            if model.isGitHubConnected {
                prominent("Continue")
            } else {
                Button("Skip for now") { step = step.next }
                    .buttonStyle(QuietButtonStyle())
                    .font(.callout.weight(.medium))
            }
        case .triage, .personalize:
            prominent("Continue")
        case .done:
            Button("Done") { finish() }
                .buttonStyle(ProminentButtonStyle(fillWidth: false))
        }
    }

    private func prominent(_ title: String) -> some View {
        Button(title) { step = step.next }
            .buttonStyle(ProminentButtonStyle(fillWidth: false))
    }

    private var dots: some View {
        HStack(spacing: Layout.snug) {
            ForEach(Step.allCases, id: \.rawValue) { s in
                Capsule()
                    .fill(s == step ? Color.appAccent : Color.appFillSelected)
                    .frame(width: s == step ? 20 : 6, height: 6)
            }
        }
        .animation(.easeOut(duration: 0.15), value: step)
    }
}

// MARK: - Step chrome

/// The centered title + one-line lead every step opens with.
private struct StepHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: Layout.snug) {
            Text(title)
                .font(.title.weight(.bold))
                .foregroundStyle(.appText)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.appTextSecondary)
                .frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }
}

// MARK: - 1 · Welcome

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: Layout.generous) {
            Spacer(minLength: Layout.generous)
            Image("AppLogo")
                .resizable()
                .frame(width: 72, height: 72)
                .clipShape(.rect(cornerRadius: 16, style: .continuous))
            StepHeader(title: "Welcome to MergeMole",
                       subtitle: "The pull requests that need you, triaged by effort and priority, right in your menu bar.")
            DemoPlaceholder()
            Spacer(minLength: Layout.generous)
        }
        .padding(.horizontal, Layout.generous * 2)
    }
}

/// Placeholder for the recorded product demo — swap this view's body for a video
/// player once the clip exists. Sized and framed so the recording drops in 1:1.
private struct DemoPlaceholder: View {
    var body: some View {
        VStack(spacing: Layout.base) {
            RoundedRectangle(cornerRadius: Layout.cardRadius)
                .fill(LinearGradient(colors: [.appAccent.opacity(0.45), .appPurple.opacity(0.45)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .foregroundStyle(Color.appAccent)
                        .frame(width: 56, height: 56)
                        .background(.white, in: Circle())
                }
            Text("See MergeMole in action · 40s")
                .font(.caption.weight(.medium))
                .foregroundStyle(.appTextSecondary)
        }
        .padding(Layout.roomy)
        .cardSurface()
        .frame(maxHeight: 340)
    }
}

// MARK: - 2 · Connect GitHub

/// The panel's connect flow, restaged for the wizard: token in, verified with
/// GitHub before it's saved (`model.connect`), then the step reads as connected.
/// The footer's Skip for now / Continue reacts to `isGitHubConnected`.
private struct ConnectStep: View {
    @Environment(AppModel.self) private var model
    @State private var token = ""
    @State private var connecting = false
    @State private var feedback: InlineFeedback?

    var body: some View {
        if model.isGitHubConnected { connected } else { form }
    }

    private var connected: some View {
        StatusScreen(
            title: "Connected to GitHub",
            message: "MergeMole is fetching your pull requests. You can fine-tune everything else in the next steps."
        ) {
            Avatar(url: model.currentUserAvatarURL, size: 56)
        } actions: {
            StatusItem(marker: .dot, text: "Connected as @\(model.currentUser)", tint: .appGreen)
                .padding(.top, Layout.generous)
        }
    }

    private var form: some View {
        StatusScreen(
            title: "Connect your GitHub",
            message: "MergeMole reads your pull requests to triage what needs your attention first. Your token stays on this Mac."
        ) {
            BrandMark(size: 46)
        } actions: {
            VStack(spacing: Layout.base) {
                SecureField("ghp_…", text: $token)
                    .font(.body.monospaced())
                    .settingsField()
                    .frame(width: 260)
                    .onSubmit { if canConnect { connect() } }
                Button("Connect") { connect() }
                    .buttonStyle(ProminentButtonStyle())
                    .frame(width: 260)
                    .disabled(!canConnect)

                switch feedback {
                case _ where connecting: InlineStatus(kind: .progress("Verifying…"))
                case .error(let m):      InlineStatus(kind: .error(m))
                default:                 EmptyView()
                }

                Link("Create a token (scopes: repo, read:org)",
                     destination: URL(string: "https://github.com/settings/tokens/new?scopes=repo,read:org&description=MergeMole")!)
                    .font(.caption)
                    .padding(.top, Layout.tight)
                Label("MergeMole only reads · your token lives in the macOS Keychain", systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(.appTextTertiary)
            }
            .padding(.top, Layout.generous)
        }
    }

    private var canConnect: Bool {
        !connecting && !GitHubToken.sanitize(token).isEmpty
    }

    /// Success needs no feedback line — the whole step re-renders as connected.
    private func connect() {
        Task {
            connecting = true
            feedback = nil
            if case .failed(let message) = await model.connect(rawToken: token) {
                feedback = .error(message)
            }
            connecting = false
        }
    }
}

// MARK: - 3 · Choose AI

/// The same three engines as Settings → Providers, same copy, same cards — the
/// wizard just frames the choice. Picking Custom model reveals the full form
/// inline, so nobody leaves setup with an engine that can't run.
private struct TriageStep: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(spacing: Layout.generous) {
                StepHeader(title: "How should MergeMole triage?",
                           subtitle: "Pick the engine that rates effort and priority. You can change this anytime in Settings.")
                VStack(spacing: Layout.base) {
                    ForEach(AIMode.allCases) { mode in
                        RadioCard(title: mode.cardTitle,
                                  detail: mode.detail,
                                  badge: mode == .onDevice ? "Recommended" : nil,
                                  warning: mode == .onDevice ? model.onDeviceUnavailableReason : nil,
                                  selected: model.aiMode == mode) {
                            model.aiMode = mode
                        }
                        if mode == .bringYourOwn && model.aiMode == .bringYourOwn {
                            CustomModelForm().cardSurface()
                        }
                    }
                }
                .animation(.easeOut(duration: 0.15), value: model.aiMode)
            }
            .padding(Layout.generous * 2)
        }
    }
}

// MARK: - 4 · Personalize

/// The two highest-leverage defaults: launch at login, and which tabs the panel
/// shows. The tab list is Settings' own `TabReorderList`, so drag-to-reorder and
/// visibility behave identically in both places. (No custom tabs can exist yet,
/// so the list's edit affordance never appears here.)
private struct PersonalizeStep: View {
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.generous) {
                StepHeader(title: "Make it yours",
                           subtitle: "A couple of defaults. Tweak everything later in Settings.")

                HStack(spacing: Layout.roomy) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at login")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.appText)
                        Text("Keep MergeMole in your menu bar automatically.")
                            .font(.caption)
                            .foregroundStyle(.appTextSecondary)
                    }
                    Spacer(minLength: Layout.base)
                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(.appAccent)
                        .onChange(of: launchAtLogin) { _, on in LoginItem.set(on) }
                }
                .cardSurface()

                VStack(alignment: .leading, spacing: Layout.snug) {
                    SectionHeader(title: "Show these tabs",
                                  subtitle: "Drag to reorder. Uncheck to hide a tab from your panel.")
                    VStack(spacing: 0) {
                        TabReorderList { _ in }
                    }
                    .cardSurface(padded: false)
                }
            }
            .padding(Layout.generous * 2)
        }
        .onAppear { launchAtLogin = LoginItem.isEnabled }
    }
}

// MARK: - 5 · All set

private struct DoneStep: View {
    var body: some View {
        StatusScreen(
            title: "You're all set",
            message: "MergeMole lives in your menu bar. Click the icon anytime to see what needs you."
        ) {
            StatusIcon(systemName: "checkmark", tint: .appAccent)
        } actions: {
            VStack(spacing: Layout.base) {
                MenuBarMock()
                Text("Look up there ↑")
                    .font(.caption)
                    .foregroundStyle(.appTextTertiary)
            }
            .padding(.top, Layout.generous)
        }
    }
}

/// A slice of menu bar with MergeMole's status item lit — a picture of where to
/// look, not a control.
private struct MenuBarMock: View {
    var body: some View {
        HStack(spacing: Layout.roomy) {
            Spacer(minLength: Layout.generous)
            HStack(spacing: 3) {
                BrandMark(size: 15, tint: .appText)
                Text("3").font(.caption.weight(.medium)).monospacedDigit()
            }
            .padding(.horizontal, Layout.snug)
            .padding(.vertical, Layout.tight)
            .background(Color.appFillSelected, in: RoundedRectangle(cornerRadius: Layout.controlRadius))
            Text("8:21 PM")
                .font(.caption)
                .foregroundStyle(.appTextSecondary)
                .padding(.trailing, Layout.roomy)
        }
        .frame(width: 300, height: 30)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.appHairline, lineWidth: 1))
    }
}

#Preview {
    OnboardingView()
        .environment(AppModel(
            prProvider: SamplePRProvider(),
            verdictEngine: SampleVerdictEngine(),
            secrets: InMemorySecretStore()
        ))
}
