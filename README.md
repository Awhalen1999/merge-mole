<div align="center">

# MergeMole

**Your GitHub pull requests, triaged by AI, in your menu bar.**

MergeMole shows your open PRs in a panel under the menu-bar icon and uses AI to tell you
what each PR *is* and what to *prioritize* — it triages, it doesn't just list.

[**Download for macOS**](https://github.com/Awhalen1999/merge-mole/releases/latest) · [Website](https://mergemole.app)

</div>

---

## Why

If you review a lot of PRs, you're drowning in them. Other menu-bar PR apps just dump a
list — you still open each one to figure out what matters. MergeMole's bet is that a short
AI verdict (a one-line summary, a priority, and one clause of *why*) turns that list into
a ranked work queue you can act on without switching to the browser.

## How it works

1. **Connect GitHub.** Paste a personal access token (`repo`, `read:org`). It's verified
   before it's saved, then stored in the macOS **Keychain** — never in plain preferences.
2. **Fetch.** One GraphQL query pulls everything waiting on you — review-requested,
   assigned, authored, mentioned, reviewed — deduped into a single list.
3. **Triage.** For each PR the chosen AI engine returns a verdict: summary, priority, and
   a short reason. Results are cached, so a PR is only re-evaluated when it actually changes.
4. **Surface.** The panel sorts by priority; the menu-bar icon carries a live count so you
   know how much is waiting without opening anything.

## AI options

- **On-device** — uses Apple's on-device model where available; nothing leaves your Mac.
- **Bring your own** — connect your own OpenAI-compatible, Anthropic, or local (Ollama)
  endpoint with your own key.
- **Off** — use MergeMole as a plain, fast PR organizer with no AI.

> Your PR **diffs are never sent** to any AI — triage runs on metadata only, so PR size
> and code privacy are never a concern.

## Privacy

Your GitHub token and any AI keys live in the macOS Keychain. There's no MergeMole
account, no telemetry server, and no backend — the app talks only to GitHub and to the AI
endpoint you choose.

## Requirements

- macOS 26.5 or later

## Updates

MergeMole updates itself via [Sparkle](https://sparkle-project.org). It checks once a day
(toggle in **Settings → About**), or check manually any time from the same place.

## Building from source

```sh
git clone https://github.com/Awhalen1999/merge-mole.git
cd merge-mole
open MergeMole.xcodeproj
```

Build and run in Xcode. The only dependency is Sparkle, resolved automatically via Swift
Package Manager.

## Contributing

MergeMole is a solo project shared in the open. Issues and PRs are welcome, but this is
maintained in spare time — please open an issue to discuss before sending a large PR, as
not every change will be merged.

## License

[MIT](LICENSE) © 2026 Alex Whalen
