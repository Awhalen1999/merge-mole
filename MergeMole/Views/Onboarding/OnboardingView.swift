import SwiftUI
import AppKit

/// First-run setup, shown in its own window (auto-presented until onboarded). Five
/// steps — Welcome → Connect → AI → Personalize → All set — on the same solid
/// Flexoki surface and card/accent conventions as Settings, so onboarding reads as
/// the same app. Chrome is consistent: a "Skip setup" escape top-right, and a
/// Back / progress-dots / primary-action bar along the bottom. Skippable; re-doable
/// from Settings.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var token = ""
    @State private var connecting = false
    @State private var connectError: String?
    @State private var launchAtLogin = LoginItem.isEnabled

    private let lastStep = 4

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, Layout.generous + Layout.snug)
                .padding(.top, Layout.headerHeight)   // clears the floating traffic lights
            bottomBar
        }
        .frame(width: 560, height: 560)
        .background(Color.appBackground)
        // Menu-bar accessory app isn't frontmost by default — bring it forward.
        .onAppear { NSApp.activate(); launchAtLogin = LoginItem.isEnabled }
    }

    // MARK: Chrome

    private var bottomBar: some View {
        ZStack {
            ProgressDots(count: lastStep + 1, current: step)
            HStack {
                if step > 0 {
                    Button("Back") { back() }
                        .buttonStyle(.plain)
                        .font(.callout)
                        .foregroundStyle(.appTextSecondary)
                }
                Spacer()
                trailingAction
            }
        }
        .frame(height: Layout.headerHeight)
        .padding(.horizontal, Layout.generous)
    }

    @ViewBuilder private var trailingAction: some View {
        switch step {
        case 0: primary("Get Started") { advance() }
        case 1: Button("Skip for now") { advance() }   // skip connecting, keep going
                    .buttonStyle(.plain).font(.callout).foregroundStyle(.appTextSecondary)
        case 2, 3: primary("Continue") { advance() }
        default: primary("Open MergeMole") { finish() }
        }
    }

    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.borderedProminent)
            .tint(.appAccent)
    }

    // MARK: Steps

    @ViewBuilder private var content: some View {
        switch step {
        case 0:  welcomeStep
        case 1:  connectStep
        case 2:  aiStep
        case 3:  personalizeStep
        default: allSetStep
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: Layout.roomy) {
            Spacer()
            AppIconTile(size: 64)
            StepHeading("Welcome to MergeMole",
                        "The pull requests that need you — triaged by priority, right in your menu bar.")
            MediaPlaceholder(height: 230)   // product demo gif drops in here later
                .padding(.top, Layout.base)
            Spacer()
        }
        .frame(maxWidth: 400)
    }

    private var connectStep: some View {
        VStack(spacing: Layout.roomy) {
            Spacer()
            StepHeading("Connect your GitHub",
                        "MergeMole reads your pull requests to triage what needs your attention first. You stay signed in on this Mac.")
            VStack(spacing: Layout.base) {
                SecureField("ghp_…", text: $token)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
                    .disabled(connecting)
                    .onSubmit(connect)

                Button(action: connect) {
                    Label("Connect to GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .buttonStyle(ProminentButtonStyle())
                .disabled(connecting || GitHubToken.sanitize(token).isEmpty)

                if connecting {
                    InlineStatus(kind: .progress("Verifying…"))
                } else if let connectError {
                    InlineStatus(kind: .error(connectError))
                }

                Link("Create a token (scopes: repo, read:org)",
                     destination: URL(string: "https://github.com/settings/tokens/new?scopes=repo,read:org&description=MergeMole")!)
                    .font(.caption)
                    .tint(.appAccent)
            }
            .frame(maxWidth: 320)

            Label("Read-only by default · verified with GitHub, stored in your Keychain.",
                  systemImage: "lock.fill")
                .font(.caption2)
                .foregroundStyle(.appTextTertiary)
                .padding(.top, Layout.tight)
            Spacer()
        }
        .frame(maxWidth: 380)
    }

    private var aiStep: some View {
        // Scrolls because picking "Custom model" reveals the full connection form,
        // which can grow past the fixed window height.
        ScrollView {
            VStack(spacing: Layout.roomy) {
                StepHeading("How should MergeMole triage?",
                            "Pick the engine that rates priority. You can change this anytime in Settings.")
                VStack(spacing: Layout.base) {
                    ForEach(AIMode.allCases) { mode in
                        RadioCard(title: mode.cardTitle,
                                  detail: mode.detail,
                                  badge: mode == .onDevice ? "Recommended" : nil,
                                  selected: model.aiMode == mode) {
                            model.aiMode = mode
                        }
                        // On-device flags when it can't run here; "Custom model"
                        // reveals the full BYO connection form — same as Settings.
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
            .frame(maxWidth: 420)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Layout.roomy)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var personalizeStep: some View {
        VStack(alignment: .leading, spacing: Layout.roomy) {
            StepHeading("Make it yours",
                        "A couple of defaults — tweak everything later in Settings.")
                .frame(maxWidth: .infinity)

            HStack(spacing: Layout.roomy) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Launch at login").font(.callout.weight(.medium)).foregroundStyle(.appText)
                    Text("Keep MergeMole in your menu bar automatically.")
                        .font(.caption).foregroundStyle(.appTextSecondary)
                }
                Spacer()
                Toggle("", isOn: $launchAtLogin)
                    .labelsHidden().toggleStyle(.switch).tint(.appAccent)
                    .onChange(of: launchAtLogin) { _, on in LoginItem.set(on) }
            }
            .cardSurface()

            VStack(alignment: .leading, spacing: Layout.snug) {
                VStack(alignment: .leading, spacing: Layout.tight) {
                    Text("SHOW THESE TABS")
                        .font(.caption2.weight(.semibold)).tracking(0.6)
                        .foregroundStyle(.appTextTertiary)
                    Text("Drag to reorder. Uncheck to hide a tab from your panel.")
                        .font(.caption).foregroundStyle(.appTextTertiary)
                }
                VStack(spacing: 0) { TabReorderList() }
                    .cardSurface(padded: false)
            }
        }
        .frame(maxWidth: 420)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, Layout.roomy)
    }

    private var allSetStep: some View {
        VStack(spacing: Layout.roomy) {
            Spacer()
            ZStack {
                Circle().fill(Color.appAccent).frame(width: 66, height: 66)
                    .shadow(color: Color.appAccent.opacity(0.45), radius: 14)
                Image(systemName: "checkmark").font(.system(size: 28, weight: .bold)).foregroundStyle(.white)
            }
            StepHeading("You're all set",
                        "MergeMole lives in your menu bar. Click the icon anytime to see what needs you.")
            VStack(spacing: Layout.snug) {
                MediaPlaceholder(height: 200)   // menu-bar reveal gif drops in here later
                Text("Look up there ↑").font(.caption).foregroundStyle(.appTextTertiary)
            }
            .padding(.top, Layout.base)
            Spacer()
        }
        .frame(maxWidth: 400)
    }

    // MARK: Flow

    private func advance() { step = min(step + 1, lastStep) }

    private func back() {
        connectError = nil
        step = max(step - 1, 0)
    }

    private func connect() {
        guard !GitHubToken.sanitize(token).isEmpty else { return }
        Task {
            connecting = true
            connectError = nil
            switch await model.connect(rawToken: token) {
            case .connected:        advance()   // straight on to the AI step
            case .failed(let msg):  connectError = msg
            }
            connecting = false
        }
    }

    private func finish() {
        model.completeOnboarding()
        dismiss()
    }
}

// MARK: - Pieces

/// A centered title + supporting line — the lead-in atop most steps.
private struct StepHeading: View {
    let title: String
    let detail: String
    init(_ title: String, _ detail: String) { self.title = title; self.detail = detail }
    var body: some View {
        VStack(spacing: Layout.snug) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.appText)
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.appTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A clean empty media frame — reserves space for a product gif we'll drop in
/// later (the welcome demo and the menu-bar reveal). No fake content by design.
private struct MediaPlaceholder: View {
    var height: CGFloat = 230
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.appSurface)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.appHairline, lineWidth: 1)
            )
    }
}

/// A progress strip: the current step is an accent capsule, the rest quiet dots.
private struct ProgressDots: View {
    let count: Int
    let current: Int
    var body: some View {
        HStack(spacing: Layout.snug) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Color.appAccent : Color.appTextTertiary.opacity(0.5))
                    .frame(width: i == current ? 18 : 6, height: 6)
            }
        }
        .animation(.easeOut(duration: 0.2), value: current)
    }
}

#Preview {
    OnboardingView()
        .environment(AppModel(secrets: InMemorySecretStore(), onboarded: false))
}
