<div align="center">

# MergeMole

**Your pull requests, triaged by AI, in your menu bar.**

MergeMole reads the PRs that need your attention and ranks them by priority and effort. Each one gets a one-line AI summary of what it does and a quick look at its review status. It's free, and by default your code never leaves your Mac.

[Download for macOS](https://github.com/Awhalen1999/merge-mole/releases/latest) · [mergemole.app](https://mergemole.app)

</div>

---

## Features

- Pulls every PR waiting on you into one list: review-requested, assigned, authored, mentioned, and reviewed.
- Ranks them by priority and effort, each with a one-line AI summary.
- Shows review state, checks, and merge status at a glance.
- Lives in the menu bar with a live count. No dock icon, no window.

## AI options

- **On-device (default):** runs locally with Apple's Foundation Models. Free, and nothing leaves your Mac.
- **Bring your own:** connect an OpenAI-compatible, Anthropic, or local (Ollama) endpoint with your own key.
- **Off:** use it as a fast, plain PR organizer.

PR diffs are never sent to any AI. Triage runs on metadata only.

## Privacy

Your GitHub token and any AI keys stay in the macOS Keychain. No account, no telemetry, no backend. The app talks only to GitHub and the AI endpoint you choose.

## Requirements

- macOS 15 (Sequoia) or later
- A GitHub personal access token (`repo`, `read:org`)
- On-device AI needs macOS 26 (Tahoe) on an Apple Silicon Mac with Apple Intelligence. On older versions, bring your own provider or turn triage off.

## Building

```sh
git clone https://github.com/Awhalen1999/merge-mole.git
cd merge-mole
open MergeMole.xcodeproj
```

The only dependency is Sparkle, resolved via Swift Package Manager.

## Contributing

Issues are welcome. ❤️

## License

[MIT](LICENSE) © 2026 Alex Whalen
