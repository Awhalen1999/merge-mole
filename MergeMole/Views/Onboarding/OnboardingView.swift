import SwiftUI

/// First-run setup, shown inside the panel until `hasCompletedOnboarding`.
/// Three short steps: welcome → connect GitHub → pick AI mode. Skippable, and
/// re-doable indirectly via Settings. Kept deliberately small (PLAN: not a maze).
struct OnboardingView: View {
    @Environment(AppModel.self) private var model

    @State private var step = 0
    @State private var token = ""
    @State private var mode: AIMode = .onDevice

    private let lastStep = 2

    var body: some View {
        VStack(spacing: Layout.roomy) {
            progress

            // Content area grows to fill; buttons stay pinned to the bottom.
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

            Link(destination: URL(string: "https://github.com/settings/tokens/new?scopes=repo,read:org&description=MergeMole")!) {
                Label("Create a token", systemImage: "arrow.up.right.square")
                    .font(.caption)
            }
            Text("Scopes needed: repo, read:org. Stored in your Keychain.")
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
            ForEach(0...lastStep, id: \.self) { i in
                Circle()
                    .fill(i <= step ? Color.appAccent : .appHairline)
                    .frame(width: 7, height: 7)
            }
            Spacer()
        }
    }

    private var buttons: some View {
        HStack(spacing: Layout.base) {
            if step > 0 {
                Button("Back") { step -= 1 }
                    .buttonStyle(.plain)
                    .foregroundStyle(.appTextSecondary)
            }
            if step == 1 {
                Button("Skip for now") { step = lastStep }
                    .buttonStyle(.plain)
                    .foregroundStyle(.appTextSecondary)
            }
            Spacer()
            Button(step == lastStep ? "Get started" : "Continue") { advance() }
                .buttonStyle(.borderedProminent)
                .tint(.appAccent)
        }
    }

    private func advance() {
        if step < lastStep {
            step += 1
        } else {
            if !token.isEmpty { model.setGitHubToken(token) }
            model.aiMode = mode
            model.completeOnboarding()
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AppModel(secrets: InMemorySecretStore(), onboarded: false))
        .frame(width: 360, height: 480)
        .background(Color.appBackground)
}
