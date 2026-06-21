# MergeMole — Guide

> A working guide, not a spec. Direction over rules. Update it as things change —
> a stale guide is worse than none.

## What it is
A macOS menu bar app that shows your GitHub pull requests in a dropdown panel
spawned from the menu bar icon. Unlike existing PR menu bar apps (PullBar, etc.),
MergeMole uses AI to tell you what each PR *is*, how much *effort* it'll take, and
what to *prioritize* — so it triages, not just lists.

First target user: an individual dev drowning in PRs. (Team/manager views are later.)

## Tech stack
- Swift + SwiftUI for the dropdown panel UI
- AppKit (`NSStatusItem`) for the menu bar icon once we want animated color states
- AI verdicts: Apple Foundation Models on-device (default), or a bring-your-own
  OpenAI-compatible endpoint, or off
- GitHub GraphQL API (one query gets PRs + review state + CI + line counts)
- Keychain for the token and any API keys
- Local JSON cache for AI verdicts (re-run only when a PR actually changes)

Platform floor: Apple Silicon (M1+), macOS version that ships Foundation Models.
Older/Intel Macs still get the PR list, just no on-device AI.

## Build order (a path, not a contract)
Build roughly one step at a time. Each should build and run before moving on.

- [x] 0. Project + MenuBarExtra (.window), LSUIElement, builds & runs
- [x] 1. `PullRequest` model + sample data + the structural seams below
- [x] 2. Card UI + tab bar — clickable cards (open the PR), hover, relative time,
       trimmed pills, shared layout scale
- [x] 3. Onboarding + Settings — standalone onboarding window + native Settings;
       GitHub token in Keychain, prefs persisted
- [x] 4. GitHub GraphQL fetch (`involves:@me`) → real PRs
- [x] 5. On-device AI — `FoundationModelsEngine` (guided generation → `Verdict`),
       availability fallback to data-only
- [x] 6. Bring-your-own — `RemoteVerdictEngine` (OpenAI-compatible, hosted or
       local Ollama/LM Studio) + endpoint/model/key fields and a Verify button
- [x] 7. Cache — `VerdictCache` (JSON on disk, keyed by engine + a content
       signature that includes the head commit SHA); unchanged PRs served
       instantly, model re-runs on any new commit or edited metadata
- [ ] 8. Menu-bar icon states (mono → amber → red), red badge, one signature polish
- [ ] UI pass — visual redesign once the logic is settled (user-driven; the data
      shown can grow/shrink to fit it)

## Structure (the seams)
Files live under `MergeMole/` (file-system-synchronized — drop in a file and Xcode
sees it). The seams let backends swap without touching callers:

- `Models/` — `PullRequest`, `Verdict` (+ `VerdictState`), `SizeBucket`. Provider-
  and AI-agnostic.
- `Services/` — swappable backends behind protocols (+ a sample impl for previews):
  - `PRProvider` → `GitHubPRProvider` (networking in `GitHubAPI`) · `SamplePRProvider`
  - `VerdictEngine` → `FoundationModelsEngine` (on-device) / `RemoteVerdictEngine`
    (BYO) / none (off) · `SampleVerdictEngine`
  - `VerdictInput` — one value derived from a `PullRequest` that produces *both*
    the engine prompt and the cache signature, so the two can never drift.
  - `SecretStore` → `KeychainSecretStore` · `InMemorySecretStore`
  - `VerdictCache`, `LoginItem`
- `State/AppModel` — `@Observable`, the single source of truth, shared across all
  scenes via `.environment`. Picks the engine from `aiMode`; depends only on protocols.
- `DesignSystem/` — `Color+Flexoki`, `Layout`, `Date+Relative`.
- `Views/` — `RootView` → `TabBar` + `PRCard`; plus `Onboarding/` and `Settings/`.
  The card branches on one `VerdictState` (off/loading/ready/failed) — never three layouts.

Concurrency: approachable concurrency (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`)
— types are main-actor by default. Network calls use async `URLSession`: the await
suspends the actor without blocking the UI, so we keep it simple on the main actor.

## AI modes (must feel seamless across all three)
Chosen in Settings → AI. The card reads one `VerdictState` and branches on it —
backend-agnostic. Adding/removing a backend is one `case` in `AppModel.activeEngine`.

1. On-device (default): Foundation Models. Free, private, no key. Cards show
   effort / summary / priority. Unavailable on this Mac → falls back to data-only.
2. Bring-your-own: any OpenAI-compatible endpoint (hosted or local Ollama). Same
   features, different backend.
3. Off: no model. Cards collapse cleanly to data-only — still a fast PR list.

Handling:
- AI-off (or unavailable) cards show no empty AI rows — as if the section never existed.
- With AI on, show a subtle loading state while a verdict computes, never a blank gap.
- Cache is keyed by engine, so switching modes re-evaluates rather than serving
  another engine's output.

## Design language
Feel target: **Obsidian + Xcode**, on the **Flexoki** palette (by Obsidian's
creator Steph Ango — same DNA). Warm paper/ink neutrals carry the layout; color
is used sparingly and only where it means something.

- **Primary accent: Flexoki Blue** (`#205EA6` light / `#4385BE` dark). Reserved
  for interactive + selection state only — never status, so it can't be mistaken
  for urgency. Xcode-native, calm.
- **Status is reserved**: red / amber / green carry CI, review, and the
  mono→amber→red escalation. The accent stays out of that lane.
- **Tokens, not hex**: `DesignSystem/Color+Flexoki.swift` holds the raw ramp plus
  *semantic* tokens (`.appAccent`, `.appBackground`, `.appSurface`, `.appText`,
  `.appTextSecondary`, `.appHairline`, `.appRed/Amber/Green`). Views reference the
  semantic names — a re-tune touches one file. AccentColor asset is set to blue so
  system controls inherit it. All tokens are light/dark adaptive.
- **Effort = neutral gauge** (intensity from the needle, no hue) so the signature
  feature doesn't collide with status colors. **Priority colors only high/urgent**
  (amber/red); low/normal stay quiet since the list is already priority-sorted.
- **Spacing/radius**: `DesignSystem/Layout.swift` holds the scale (hair/tight/snug/
  base/roomy + `cardRadius` 10). Views use the names, never raw numbers.
- **Type**: native macOS text styles — a clean built-in hierarchy, no custom sizes.

## Onboarding & Settings
Feel target: Rectangle / Obsidian. Native, sectioned Settings; a short first-run
flow that gets to value fast.

**Settings window** — native SwiftUI `Settings` scene (⌘,), a `TabView` of
system-native sections (`Form` controls + blue accent), not the panel's Flexoki
surface — most macOS-correct, lowest bug surface.
- General — launch at login (`SMAppService`), Reset MergeMole (replay setup).
- GitHub — connection status, paste/replace token (verified before saving), disconnect.
- AI — mode picker; BYO reveals endpoint + model + key, with a Verify button.
- About — version, privacy line, repo link.

The panel header carries refresh / settings / quit icon buttons (AI mode lives in
Settings, not the header).

**First-run onboarding** — `OnboardingView`, a standalone `Window` scene that
auto-presents at launch until `hasCompletedOnboarding` (via `defaultLaunchBehavior`,
read from UserDefaults), then dismisses itself; brought to front via `NSApp.activate`.
Three steps: Welcome → Connect GitHub (paste token + "create one" link, scopes
`repo`, `read:org`; skippable, verified inline) → Choose AI mode. PAT for v1.

**Token safety** — a token is *never* stored unverified. `AppModel.connect`
sanitizes the input (strips whitespace), calls `GitHubAPI.viewerLogin` to verify,
and only then saves to the Keychain. Both Settings and onboarding surface
"Connected as *login*" or the error.

**Persistence** — token + BYO API key via `KeychainSecretStore` (never UserDefaults).
Non-secret prefs (AI mode, BYO endpoint + model, `hasCompletedOnboarding`) are
AppModel properties backed by UserDefaults. AppModel is shared across scenes via
`.environment`. (Auto-refresh + a refresh-interval setting come with the badge, Step 8.)

## Guiding principles
- Every AI verdict shows one clause of *why*. Auditable, never a black box.
- The PR list works perfectly with AI off — that's a first-class mode, not a fallback.
- The red badge errs toward missing over crying wolf. Start conservative; loosen later.
- Show the AI effort tier next to the native line counts, never instead of — the
  contrast is the feature.
- Cache hard: re-run a verdict only when the PR's reviewable content changes.
- Secrets live in Keychain, never UserDefaults. Never store a credential unverified.

## Monetization
Free. On-device AI and AI-off cost nothing to run; BYO-key means the user covers
their own hosted usage. No paid tier or billing in v1. Revisit only if hosted-AI
cost ever lands on us.

## Not now (keep v1 focused)
- Connectors (Jira, Linear, Slack, CI beyond GitHub)
- Team / lead / manager views
- Approve-PR-from-menu (accidental approvals lose trust)
- Analytics / dashboards
- Paid tier / billing

BYO-key, custom endpoint, and AI-off *are* in scope — core to "use it however you
want." OAuth (vs. paste-a-token) is the main thing deferred past v1.
