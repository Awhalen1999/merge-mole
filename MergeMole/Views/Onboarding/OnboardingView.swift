import SwiftUI
import AppKit
import AVKit

/// The first-run setup wizard: welcome → connect GitHub → choose AI → personalize
/// → unread → done, in its own window (see the scene in `MergeMoleApp`). Every
/// step edits the live `AppModel` directly, exactly like Settings does — there's
/// nothing to apply or roll back, so Back and Skip need no bookkeeping. Finishing
/// (or skipping) records completion and closes the window; the panel takes it
/// from there.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismissWindow) private var dismissWindow

    static let windowID = "onboarding"

    /// The six steps, in order. Raw values give Back/Continue for free.
    private enum Step: Int, CaseIterable {
        case welcome, connect, triage, personalize, unread, done

        var next: Step { Step(rawValue: rawValue + 1) ?? self }
        var previous: Step { Step(rawValue: rawValue - 1) ?? self }
    }

    @State private var step: Step = .welcome

    /// How far Skip lifts out of the content into the hidden title bar, so it
    /// sits level with the traffic lights instead of below the strip.
    private static let titleBarLift: CGFloat = 24

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Hairline()
                footer
            }
            // Skip is always available until the last step, where Done takes over.
            // Sits in the title-bar row, opposite the traffic lights.
            if step != .done {
                Button("Skip setup") { finish() }
                    .buttonStyle(QuietButtonStyle())
                    .font(.callout.weight(.medium))
                    .padding(.trailing, Layout.generous)
                    .offset(y: -Self.titleBarLift)
            }
        }
        .frame(width: 620, height: 600)
        // The background alone escapes the safe area, painting the hidden
        // title-bar strip to match — the content keeps its normal bounds, so the
        // footer stays flush with the window's bottom edge.
        .background(Color.appBackground.ignoresSafeArea())
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
        case .unread:      UnreadStep()
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
                Button("Not now") { step = step.next }
                    .buttonStyle(QuietButtonStyle())
                    .font(.callout.weight(.medium))
            }
        case .triage, .personalize, .unread:
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

/// A step's content area with one shared inset: centered while it fits the
/// window, scrolling only when it outgrows it (e.g. the custom-model form).
private struct WizardPage<Content: View>: View {
    @ViewBuilder var content: Content

    /// How far scrolled-away content fades out under the window's top chrome
    /// (traffic lights, Skip) instead of hitting an invisible bar. Covers the
    /// title-bar strip with room for the dissolve to read as gradual.
    /// (Instance, not static — generic types can't store static properties.)
    private let topFade: CGFloat = 56

    var body: some View {
        ViewThatFits(in: .vertical) {
            inner
            ScrollView { inner }
                .mask {
                    VStack(spacing: 0) {
                        LinearGradient(colors: [.clear, .black],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: topFade)
                        Color.black
                    }
                }
        }
    }

    private var inner: some View {
        VStack(spacing: Layout.generous) { content }
            .padding(Layout.generous * 2)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - 1 · Welcome

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: Layout.generous) {
            Image("AppLogo")
                .resizable()
                .frame(width: 56, height: 56)
                .clipShape(.rect(cornerRadius: 12, style: .continuous))
            StepHeader(title: "Welcome to MergeMole",
                       subtitle: "The pull requests that need you, triaged by effort and priority, right in your menu bar.")
            DemoVideo()
        }
        .padding(Layout.generous * 2)
    }
}

/// The product demo (Resources/demo.mp4) looping silently, no controls. It takes
/// whatever height the welcome step has left and keeps the clip's own aspect, so
/// the width follows the recording — swap the asset and the frame adapts.
/// Falls back to the design placeholder if the resource ever goes missing.
private struct DemoVideo: View {
    private static let url = Bundle.main.url(forResource: "demo", withExtension: "mp4")

    /// The clip's aspect, read from the asset when the step appears. The seed
    /// value matches the current recording, so there's no first-frame reflow;
    /// a swapped recording re-shapes the frame on load.
    @State private var aspect = CGSize(width: 1280, height: 1280)

    var body: some View {
        if let url = Self.url {
            LoopingPlayerView(url: url)
                .aspectRatio(aspect, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Layout.cardRadius))
                .frame(maxWidth: .infinity)
                .task {
                    guard let track = try? await AVURLAsset(url: url).loadTracks(withMediaType: .video).first,
                          let size = try? await track.load(.naturalSize) else { return }
                    aspect = CGSize(width: abs(size.width), height: abs(size.height))
                }
        } else {
            DemoPlaceholder()
        }
    }
}

/// Chromeless looping video — an `AVPlayerLayer` (no `VideoPlayer` controls)
/// fed by an `AVPlayerLooper` for a seamless repeat, muted.
private struct LoopingPlayerView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> PlayerView { PlayerView(url: url) }
    func updateNSView(_ view: PlayerView, context: Context) {}

    final class PlayerView: NSView {
        private let playerLayer = AVPlayerLayer()
        private let player = AVQueuePlayer()
        private var looper: AVPlayerLooper?

        init(url: URL) {
            super.init(frame: .zero)
            wantsLayer = true
            player.isMuted = true
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            playerLayer.player = player
            playerLayer.videoGravity = .resizeAspect
            layer?.addSublayer(playerLayer)
            player.play()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        override func layout() {
            super.layout()
            playerLayer.frame = bounds
        }
    }
}

/// The design-time stand-in, kept only as `DemoVideo`'s missing-asset fallback.
private struct DemoPlaceholder: View {
    var body: some View {
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
    }
}

// MARK: - 2 · Connect GitHub

/// The panel's connect flow, restaged for the wizard: token in, verified with
/// GitHub before it's saved (`model.connect`), then the step reads as connected.
/// The footer's Not now / Continue reacts to `isGitHubConnected`.
private struct ConnectStep: View {
    @Environment(AppModel.self) private var model
    @State private var token = ""
    @State private var connecting = false
    @State private var feedback: InlineFeedback?

    /// The token field and its Connect button share one width, so the form
    /// reads as a single column.
    private static let formWidth: CGFloat = 260

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
            EmptyView()   // the form is the focus; no glyph needed above it
        } actions: {
            VStack(spacing: Layout.base) {
                SecureField("ghp_…", text: $token)
                    .font(.body.monospaced())
                    .settingsField()
                    .frame(width: Self.formWidth)
                    .onSubmit { if canConnect { connect() } }
                Button("Connect") { connect() }
                    .buttonStyle(ProminentButtonStyle())
                    .frame(width: Self.formWidth)
                    .disabled(!canConnect)

                if connecting {
                    InlineStatus(kind: .progress("Verifying…"))
                } else if case .error(let message) = feedback {
                    InlineStatus(kind: .error(message))
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
        WizardPage {
            StepHeader(title: "How should MergeMole triage?",
                       subtitle: "Pick the engine that rates effort and priority. You can change this anytime in Settings.")
            VStack(spacing: Layout.base) {
                ForEach(AIMode.allCases) { mode in
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
                                  badge: mode == .onDevice ? "Recommended" : nil,
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

// MARK: - 4 · Personalize

/// The highest-leverage defaults, with Settings' own components so everything
/// behaves identically in both places: launch at login, refresh cadence, and
/// the tab list (`TabReorderList` + `NewTabRow`, custom tabs included). The
/// attention choices (unread mode, menu-bar count) get their own step next,
/// mirroring the Settings tab split.
private struct PersonalizeStep: View {
    @Environment(AppModel.self) private var model
    @State private var launchAtLogin = LoginItem.isEnabled
    /// The custom-tab sheet, when open — creating a new tab or editing one.
    @State private var editing: CustomTabEditor.Mode?

    var body: some View {
        @Bindable var model = model
        WizardPage {
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

            HStack(spacing: Layout.roomy) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Refresh automatically")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.appText)
                    Text("How often MergeMole checks GitHub for changes.")
                        .font(.caption)
                        .foregroundStyle(.appTextSecondary)
                }
                Spacer(minLength: Layout.base)
                Picker("", selection: $model.refreshInterval) {
                    ForEach(RefreshInterval.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
            .cardSurface()

            VStack(alignment: .leading, spacing: Layout.snug) {
                SectionHeader(title: "Show these tabs",
                              subtitle: "Drag to reorder. Uncheck to hide a tab from your panel. New Custom Tab turns any GitHub search into a tab of your own.")
                VStack(spacing: 0) {
                    TabReorderList { editing = .edit($0) }
                    Hairline()
                    NewTabRow { editing = .create }
                }
                .cardSurface(padded: false)
            }

        }
        .onAppear { launchAtLogin = LoginItem.isEnabled }
        .sheet(item: $editing) { mode in
            CustomTabEditor(mode: mode)
        }
    }
}

// MARK: - 5 · Unread

/// The attention step — the same choice as Settings → Unread, framed as a
/// question, plus which groups feed the menu-bar count (`BadgeTabList`) and a
/// notifications opt-in. The toggle rides this step because notifications have
/// no model of their own: they follow the choice the user just made, and
/// flipping it on fires the macOS permission prompt at the moment of maximum
/// intent (the `notificationsEnabled` didSet). Ships unchecked; a declined
/// prompt is silently fine here — Settings → Unread surfaces the blocked state
/// later, and the wizard never grows error branches. The per-signal checkboxes
/// stay in Settings, with the subtitle pointing the way.
private struct UnreadStep: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        WizardPage {
            StepHeader(title: "What counts as unread?",
                       subtitle: "Pick what the unread dot, menu-bar count, and notifications flag. Fine-tune which activity counts anytime in Settings → Unread.")

            VStack(spacing: Layout.base) {
                ForEach(UnreadMode.allCases) { mode in
                    // Activity grows its card to hold the signal checkboxes —
                    // the same list as Settings → Unread, same expansion move
                    // as the custom-model card on the AI step.
                    if mode == .activity {
                        RadioCard(title: mode.label,
                                  detail: mode.detail,
                                  selected: model.unreadMode == mode) {
                            model.unreadMode = mode
                        } expansion: {
                            UnreadSignalList()
                        }
                    } else {
                        RadioCard(title: mode.label,
                                  detail: mode.detail,
                                  selected: model.unreadMode == mode) {
                            model.unreadMode = mode
                        }
                    }
                }
            }
            .animation(.easeOut(duration: 0.15), value: model.unreadMode)

            VStack(alignment: .leading, spacing: Layout.snug) {
                SectionHeader(title: "Menu-bar count",
                              subtitle: "Pick which groups feed the unread count on the menu-bar icon. Each PR counts once.")
                VStack(spacing: 0) {
                    BadgeTabList()
                }
                .cardSurface(padded: false)
            }

            VStack(alignment: .leading, spacing: Layout.snug) {
                SectionHeader(title: "Notifications",
                              subtitle: "A desktop notification when a watched PR turns unread. Follows the choices above and clears when you catch up.")
                HStack(spacing: Layout.roomy) {
                    Text("Notify when a PR turns unread")
                        .foregroundStyle(.appText)
                    Spacer(minLength: Layout.base)
                    Toggle("", isOn: $model.notificationsEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(.appAccent)
                }
                .padding(.horizontal, Layout.roomy)
                .padding(.vertical, Layout.base + 2)
                .cardSurface(padded: false)
            }
        }
    }
}

// MARK: - 6 · All set

private struct DoneStep: View {
    @Environment(AppModel.self) private var model

    /// Drives the arrow's gentle bob toward the menu bar.
    @State private var bobbing = false

    /// The setup receipt — what this run actually configured, one quiet line.
    /// Reads from live state, so a skipped connect shows the next step instead
    /// of claiming a connection that isn't there.
    private var recap: String {
        var parts = [
            model.isGitHubConnected ? "Connected as @\(model.currentUser)"
                                    : "Connect GitHub anytime in Settings",
        ]
        switch model.aiMode {
        case .onDevice:     parts.append("On-device AI")
        case .bringYourOwn: parts.append("Custom model")
        case .off:          parts.append("AI off")
        }
        let tabs = model.visibleTabs.count
        parts.append("\(tabs) tab\(tabs == 1 ? "" : "s")")
        switch model.unreadMode {
        case .newOnly:  parts.append("Unread: new PRs only")
        case .activity: parts.append("Unread: PR activity")
        }
        if model.notificationsEnabled { parts.append("Notifications on") }
        return parts.joined(separator: " · ")
    }

    /// True only when the "your PRs are imported" promise is — the skipped-connect
    /// run keeps the generic line instead of claiming an import that never ran.
    private var message: String {
        model.isGitHubConnected
            ? "MergeMole lives in your menu bar. Your open PRs are already imported, the menu bar icon will update when new ones arrive or something changes."
            : "MergeMole lives in your menu bar. Click the icon anytime to see what needs you."
    }

    var body: some View {
        StatusScreen(
            title: "You're all set",
            message: message,
            footnote: recap
        ) {
            // Green, not accent: success is green everywhere in the app (Connected
            // dots, ok-status checks); the accent stays on the Done button alone.
            StatusIcon(systemName: "checkmark", tint: .appGreen)
        } actions: {
            // The custom alignment pins the arrow directly under MergeMole's
            // status item in the mock, so it points at the icon itself.
            VStack(alignment: .menuBarMole, spacing: Layout.tight) {
                MenuBarMock()
                Image(systemName: "arrow.up")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.appTextTertiary)
                    .padding(.top, Layout.tight)
                    .alignmentGuide(.menuBarMole) { $0[HorizontalAlignment.center] }
                    // A quiet bob toward the icon — enough to draw the eye up.
                    .offset(y: bobbing ? -2 : 2)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: bobbing)
                    .onAppear { bobbing = true }
            }
            .padding(.top, Layout.generous)
        }
    }
}

/// Where MergeMole's status item sits in the mock — the pointing arrow aligns
/// its center to the pill's.
private extension HorizontalAlignment {
    private struct MenuBarMole: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[HorizontalAlignment.center]
        }
    }
    static let menuBarMole = HorizontalAlignment(MenuBarMole.self)
}

/// A slice of menu bar with MergeMole's status item lit among the usual system
/// items — a picture of where to look, not a control. Deliberately no badge
/// number: the first sync seeds everything as read (`reconcileReadState`), so
/// the real icon is always bare at this moment — a count here would promise
/// something the menu bar isn't showing.
private struct MenuBarMock: View {
    var body: some View {
        HStack(spacing: Layout.generous) {
            Spacer(minLength: Layout.generous)
            BrandMark(size: 17, tint: .appText)
                .padding(.horizontal, Layout.snug)
                .padding(.vertical, Layout.tight)
                .background(Color.appFillSelected, in: RoundedRectangle(cornerRadius: Layout.controlRadius))
                .alignmentGuide(.menuBarMole) { $0[HorizontalAlignment.center] }
            Image(systemName: "battery.75percent")
            Image(systemName: "wifi")
            Image(systemName: "magnifyingglass")
            Image(systemName: "switch.2")
            Text("Sat Aug 1  9:41 AM")
                .padding(.trailing, Layout.roomy)
        }
        .font(.callout)
        .foregroundStyle(.appTextSecondary)
        .frame(width: 380, height: 34)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: Layout.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Layout.cardRadius).strokeBorder(Color.appHairline, lineWidth: 1))
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
