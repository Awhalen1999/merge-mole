<div align="center">
  <img src=".github/assets/app-icon.png" width="180" height="180" alt="MergeMole icon">

# MergeMole

</div>

MergeMole is a menu bar app that triages your pull requests with AI. It pulls every PR that needs your attention into one list and ranks each by priority and effort, with a one-line summary of what it does. It's free, and by default your code never leaves your Mac.

<img width="480" height="668" alt="demo-screenshot" src="https://github.com/user-attachments/assets/73cc06bc-539a-4678-b4a2-663d410f0d0a" />


[![download](https://img.shields.io/github/v/release/Awhalen1999/merge-mole?label=download&color=brightgreen)](https://github.com/Awhalen1999/merge-mole/releases/latest)
![platform](https://img.shields.io/badge/platform-macOS-blue)
![requirements](https://img.shields.io/badge/requirements-macOS%2015%2B-fa4e49)
[![website](https://img.shields.io/badge/Website-mergemole.app-4a90d9)](https://mergemole.app)
[![license](https://img.shields.io/github/license/Awhalen1999/merge-mole?color=orange)](LICENSE)

> [!NOTE]
> On-device AI triage requires macOS 26 (Tahoe) on an Apple Silicon Mac with Apple Intelligence. On macOS 15, bring your own model or use MergeMole as a fast, plain PR organizer.

## Install

Download the latest release [here](https://github.com/Awhalen1999/merge-mole/releases/latest) or from [mergemole.app](https://mergemole.app), open the DMG, and move MergeMole into your `Applications` folder.

You'll need a GitHub personal access token (scopes: `repo`, `read:org`). MergeMole walks you through creating one on first launch.

## Features/Roadmap

> [!NOTE]
> MergeMole is currently in active development. Some features have not yet been implemented. Download the latest release [here](https://github.com/Awhalen1999/merge-mole/releases/latest) and see the roadmap below for upcoming features.

- [x] Menu bar panel: every PR waiting on you in one list
- [x] Built-in tabs: review requested, assigned, created, mentioned, and reviewed
- [x] AI triage: priority and effort ratings, plus a one-line summary of each PR
- [x] On-device AI with Apple's Foundation Models
- [x] Bring-your-own model: OpenAI-compatible, Anthropic, or local (Ollama)
- [x] Smart verdict caching: a PR only re-analyzes when it meaningfully changes
- [x] Read/unread tracking with a live menu bar count
- [x] Review state, CI checks, merge conflicts, and size at a glance
- [x] Automatic updates, with signed and notarized releases
- [x] Panel appearance options: solid or transparent background, detailed or compact cards
- [x] Custom tabs: turn any GitHub search into a tab of your own
- [x] Configurable refresh, from every minute to manual
- [x] Include or exclude PRs from archived repositories
- [x] Launch at login
- [x] First-run onboarding flow
- [ ] Stacked PR support
- [ ] Compact card updates

## AI options

- **On-device (default):** runs locally with Apple's Foundation Models. Free, and nothing leaves your Mac.
- **Bring your own:** connect an OpenAI-compatible, Anthropic, or local (Ollama) endpoint with your own key.
- **Off:** use it as a fast, plain PR organizer.

## Privacy

Your GitHub token and any AI keys stay in the macOS Keychain. No account, no telemetry, no backend. The app talks only to GitHub and the AI endpoint you choose.

## Why does on-device AI need macOS 26?

MergeMole's on-device triage is built on Apple's Foundation Models framework, which ships with macOS 26 and needs an Apple Silicon Mac with Apple Intelligence enabled. Everything else in the app works on macOS 15, where you can pair it with your own model or run triage off.

## Contributing

Issues are welcome. ❤️

## License

MergeMole is available under the [MIT license](LICENSE).
