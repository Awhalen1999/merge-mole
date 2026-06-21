import SwiftUI
import AppKit

/// First-run setup, shown in its own window (auto-presented at launch until
/// `hasCompletedOnboarding`). Three short steps: welcome → connect GitHub → pick
/// AI mode. Skippable; re-doable from Settings. Small by design (PLAN: not a maze).
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var token = ""
    @State private var mode: AIMode = .onDevice
    @State private var connecting = false
    @State private var connectError: String?

    private let lastStep = 2

    var body: some View {
        VStack(spacing: Layout.roomy) {
            progress

            // Content grows to fill; buttons stay pinned to the bottom.
            VStack(alignment: .leading, spacing: Layout.base) {
                switch step {
                case 0: welcome
                case 1: connectGitHub
                default: aiMode
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            buttons
        }
        .padding(Layout.roomy + Layout.base)
        .frame(width: 460, height: 420)
        .background(Color.appBackground)
        // Bring the window to the front at launch (the app is a menu-bar
        // accessory, so it isn't frontmost by default).
        .onAppear { NSApp.activate() }
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(alignment: .leading, spacing: Layout.base) {
            Image(systemName: "circle.grid.2x2.fill")
                .font(.largeTitle)
                .foregroundStyle(Color.appAccent)
            Text("Welcome to MergeMole")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.appText)
            Text("Your pull requests in the menu bar — triaged. On-device AI tells you what each PR is, how much effort it'll take, and what to look at first.")
                .font(.callout)
                .foregroundStyle(.appTextSecondary)
        }
    }

    private var connectGitHub: some View {
        VStack(alignment: .leading, spacing: Layout.base) {
            Text("Connect GitHub")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.appText)
            Text("Paste a personal access token so MergeMole can read your pull requests.")
                .font(.callout)
                .foregroundStyle(.appTextSecondary)

            SecureField("ghp_…", text: $token)
                .textFieldStyle(.roundedBorder)
                .font(.body.monospaced())
                .disabled(connecting)

            if let connectError {
                Label(connectError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.appRed)
            }

            Link(destination: URL(string: "https://github.com/settings/tokens/new?scopes=repo,read:org&description=MergeMole")!) {
                Label("Create a token", systemImage: "arrow.up.right.square")
                    .font(.caption)
            }
            Text("Scopes needed: repo, read:org. Verified with GitHub, then stored in your Keychain.")
                .font(.caption2)
                .foregroundStyle(.appTextTertiary)
        }
    }

    private var aiMode: some View {
        VStack(alignment: .leading, spacing: Layout.base) {
            Text("How should AI run?")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.appText)
            Picker("AI mode", selection: $mode) {
                ForEach(AIMode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Text(mode.detail)
                .font(.callout)
                .foregroundStyle(.appTextSecondary)
            Text("You can change this any time in Settings.")
                .font(.caption2)
                .foregroundStyle(.appTextTertiary)
        }
    }

    // MARK: Chrome

    private var progress: some View {
        HStack(spacing: Layout.snug) {
            ForEach(0...lastStep, id: \.self) { index in
                Circle()
                    .fill(index <= step ? Color.appAccent : .appHairline)
                    .frame(width: 7, height: 7)
            }
            Spacer()
        }
    }

    private var buttons: some View {
        HStack(spacing: Layout.base) {
            if step > 0 {
                Button("Back") { back() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.appTextSecondary)
            }
            if step == 1 {
                Button("Skip for now") { step = lastStep }
                    .buttonStyle(.plain)
                    .foregroundStyle(.appTextSecondary)
            }
            Spacer()
            if connecting { ProgressView().controlSize(.small) }
            Button(step == lastStep ? "Get started" : "Continue") { advance() }
                .buttonStyle(.borderedProminent)
                .tint(.appAccent)
                .disabled(connecting)
        }
    }

    // MARK: Flow

    private func advance() {
        switch step {
        case 1 where !GitHubToken.sanitize(token).isEmpty:
            Task { await connectThenContinue() }   // verify the token before moving on
        case lastStep:
            finish()
        default:
            step += 1
        }
    }

    private func connectThenContinue() async {
        connecting = true
        connectError = nil
        switch await model.connect(rawToken: token) {
        case .connected:
            step += 1
        case .failed(let message):
            connectError = message
        }
        connecting = false
    }

    private func back() {
        connectError = nil
        step -= 1
    }

    private func finish() {
        model.aiMode = mode
        model.completeOnboarding()
        dismiss()
    }
}

#Preview {
    OnboardingView()
        .environment(AppModel(secrets: InMemorySecretStore(), onboarded: false))
}
