# MergeMole — Guide

> A working guide, not a spec. Direction over rules. Update it as things change —
> a stale guide is worse than none.

## What it is
A macOS menu bar app that shows your GitHub pull requests in a dropdown panel
spawned from the menu bar icon. Unlike existing PR menu bar apps (PullBar, etc.),
MergeMole uses on-device AI to tell you what each PR *is*, how much *effort* it'll
take, and what to *prioritize* — so it triages, not just lists.

First target user: an individual dev drowning in PRs. (Team/manager views are later.)

## Tech stack
- Swift + SwiftUI for the dropdown panel UI
- AppKit (`NSStatusItem`) for the menu bar icon once we want animated color states
- On-device AI: Apple Foundation Models (free, private, no API key)
- GitHub GraphQL API (one query gets PRs + review state + CI + line counts)
- Keychain for the token and any API keys
- Local JSON/SQLite cache for PRs + AI digests

Platform floor: Apple Silicon (M1+), macOS version that ships Foundation Models.
Older/Intel Macs still get the PR list, just no on-device AI.

## Build order (a path, not a contract)
Build roughly one step at a time. Each should build and run before moving on.

- [x] 0. Project created, MenuBarExtra (.window), LSUIElement=YES, builds & runs
- [x] 1. `PullRequest` model + fake sample data (+ the structural seams below)
- [x] 2. Card UI + tab bar, against fake data — polished: clickable cards (open
       the PR), hover affordance, relative time, trimmed pills, layout scale
- [x] 3. Onboarding + Settings: native Settings window + in-panel first-run flow.
       GitHub token in Keychain, prefs persisted. Unblocks real data (Step 4).
- [x] 4. GitHub GraphQL fetch using the stored token → real PRs (involves:@me)
- [ ] 5. Cache + re-digest only when the diff actually changes
- [ ] 6. On-device AI: effort tier first, then summary, then priority
       (wire the BYO key + endpoint from Settings here)
- [ ] 7. Icon states (mono → amber → red), then red badge, then one signature polish

## Structure (the seams)
Files are grouped under `MergeMole/` (file-system-synchronized — drop a file in
and Xcode sees it). The point is that later steps swap implementations, not
rewrite callers:
- `Models/` — `PullRequest`, `Verdict`, `SizeBucket`. Provider-agnostic.
- `Sample/` — `SampleData`: the only fake data. Delete it when real data lands.
- `Services/` — protocols + sample impls:
  - `PRProvider` → `GitHubPRProvider` at Step 4
  - `VerdictEngine` → on-device / BYO engines at Step 6 (AI-off = no engine)
  - `SecretStore` → `KeychainSecretStore` at Step 3
- `State/AppModel` — `@Observable`, the single source of truth. Holds PRs, a
  `VerdictState` per PR, the tab, and the AI mode. Depends only on the protocols.
- `Views/` — `RootView` → `TabBar` + `PRCard`. The card branches on one
  `VerdictState` (`off`/`loading`/`ready`/`failed`) — never three layouts.

Concurrency: target uses approachable concurrency (`SWIFT_DEFAULT_ACTOR_ISOLATION
= MainActor`), so types are main-actor by default; mark real I/O `nonisolated`.

## Design language
Feel target: **Obsidian + Xcode**, on the **Flexoki** palette (by Obsidian's
creator Steph Ango — same DNA). Warm paper/ink neutrals carry the layout;
color is used sparingly and only where it means something.

- **Primary accent: Flexoki Blue** (`#205EA6` light / `#4385BE` dark). Reserved
  for interactive + selection state only — never status, so it can't be mistaken
  for urgency. Xcode-native, calm.
- **Status is reserved**: red / amber / green carry CI, review, and the
  mono→amber→red escalation. The accent stays out of that lane.
- **Tokens, not hex**: `DesignSystem/Color+Flexoki.swift` holds the raw ramp plus
  *semantic* tokens (`.appAccent`, `.appBackground`, `.appSurface`, `.appText`,
  `.appTextSecondary`, `.appHairline`, `.appRed/Amber/Green`). Views reference the
  semantic names — a re-tune touches one file. AccentColor asset is set to blue
  so system controls inherit it. All tokens are light/dark adaptive.
- **Effort = neutral gauge** (intensity from the needle, no hue) so the signature
  feature doesn't collide with status colors. **Priority colors only high/urgent**
  (amber/red); low/normal stay quiet since the list is already priority-sorted.
- **Spacing/radius**: `DesignSystem/Layout.swift` holds the scale (hair/tight/
  snug/base/roomy + `cardRadius` 10). Views use the names, never raw numbers.
- **Type**: native macOS text styles (`.headline` title, `.caption`/`.caption2`
  metadata) — a clean built-in hierarchy, no custom font sizes to drift.

## Onboarding & Settings  (built — Step 3)
Feel target: Rectangle / Obsidian. Native, sectioned Settings; a short first-run
flow that gets to value fast.

**Settings window** — native SwiftUI `Settings` scene (⌘, ), a `TabView` with
tabbed sections. Kept system-native (`Form` controls + blue accent), not the
panel's Flexoki surface — most macOS-correct, lowest bug surface.
- General — launch at login (`SMAppService`), refresh interval.
- GitHub — connection status, paste/replace token, disconnect.
- AI — mode picker (on-device / BYO / off). BYO reveals endpoint URL + API key.
- About — version, privacy line, repo link.

The temporary AI-mode picker is gone from the panel header; AI mode now lives in
Settings. The header carries refresh / settings / quit icon buttons instead.

**First-run onboarding** — `OnboardingView`, a standalone `Window` scene that
auto-presents at launch until `hasCompletedOnboarding` (via
`defaultLaunchBehavior`, read from UserDefaults), then dismisses itself. Comes to
front via `NSApp.activate`. Three steps: Welcome → Connect GitHub (paste token +
"create one" link, scopes `repo`, `read:org`; skippable) → Choose AI mode. PAT
paste for v1; OAuth later.

**Persistence** — token + BYO API key via `KeychainSecretStore` (Security
framework, delete-then-add), never UserDefaults. Non-secret prefs (AI mode, BYO
endpoint, refresh interval, `hasCompletedOnboarding`) are AppModel properties
backed by UserDefaults. AppModel is shared across both scenes via `.environment`.

## AI modes (must feel seamless across all three)
The user picks, in advanced settings, how AI runs. The card UI should read from a
single verdict value that's either present or absent, and branch on that — not three
separate layouts.

1. On-device (default): Foundation Models. Cards show effort / summary / priority.
2. Bring-your-own model: user supplies an API key + custom endpoint URL
   (covers hosted models and local ones like Ollama). Same features, different backend.
3. AI off: no model. Cards collapse cleanly to data-only — title, repo, branch,
   line counts, native size bucket. Still fully useful as a fast PR list.

Handling:
- AI-off cards show no empty AI rows — they look as if the AI section never existed.
- With AI on, show a subtle loading state while a verdict computes, never a blank gap.

## Guiding principles
- Every AI verdict shows one clause of *why*. Auditable, never a black box.
- The PR list works perfectly with AI off — that's a first-class mode, not a fallback.
- The red badge errs toward missing over crying wolf. Start conservative; loosen later.
- Show the AI effort tier next to the native line counts, never instead of — the
  contrast is the feature.
- Cache hard: re-summarize a PR only when its diff changes.
- Secrets live in Keychain, never UserDefaults.

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
BYO-key, custom endpoint, and AI-off *are* in scope — they're core to "use it however you want."
A short onboarding flow and a native Settings window *are* in scope too (Step 3).
OAuth (vs. paste-a-token) and launch-at-login can come after v1 if they slip.
