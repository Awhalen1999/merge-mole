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
- [x] 4. GitHub GraphQL fetch → real PRs. One query, five aliased searches
       (`review-requested` / `assignee` / `author` / `mentions` / `reviewed-by` `:@me`),
       deduped into one list; each PR carries its `relationships`. Tabs are one
       per relationship, with a configurable visible set (Settings → General → Tabs;
       default: Review Requested / Assigned / Created). Per-PR fields also include
       merge-conflict state, comment count, and createdAt.
- [x] 5. On-device AI — `FoundationModelsEngine` (guided generation → `Verdict`),
       availability fallback to data-only
- [x] 6. Bring-your-own — `RemoteVerdictEngine` (OpenAI-compatible, hosted or
       local Ollama/LM Studio) + endpoint/model/key fields and a Verify button
- [x] 7. Cache — `VerdictCache` (JSON on disk, keyed by engine + a content
       signature that includes the head commit SHA); unchanged PRs served
       instantly, model re-runs on any new commit or edited metadata
- [x] 8. Auto-refresh + badge — energy-aware background refresh
       (`NSBackgroundActivityScheduler`, plus refresh-on-wake and -on-network-return;
       interval set in Settings → General). The menu-bar item shows a live count of
       review-requested PRs (`AppModel.badgeCount`).
- [x] UI pass — full visual redesign on a native-macOS palette: a Transparent/Solid
       panel backdrop, a 3-tab Settings window, and a 5-step onboarding flow.
       See **Design language** and **Onboarding & Settings** below.
- [x] 9. Menu-bar polish — custom mole-in-a-burrow template icon: an empty hole
       when nothing's waiting, a mole rising out of it when PRs await review
       (switched on `badgeCount`), with the live count beside it as text. Done in
       the `MenuBarExtra` label with template assets. Source SVGs in
       `Design/menubar-icons/` (variant C shipped as `HoleMole`; B kept as the
       alternate).
       Priority color escalation (mono → amber → red) was tried and dropped:
       `MenuBarExtra` renders its whole label monochrome, so neither a tinted
       template image nor colored count text shows any color. Revisit later with
       non-template colored assets (or a real `NSStatusItem`) if we want it.
- [ ] 10. Test target — unit tests over the pure logic (`VerdictInput.signature`,
       `EffortTier`/`Priority(wire:)`, `SizeBucket`, `PRTab` order restore,
       `VerdictCache.prune`, `RemoteVerdictEngine.completionsURL`, the GraphQL merge).

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
Feel target: a **native macOS app** — System-Settings-grade neutrals and controls,
with one brand accent. Color is used sparingly and only where it means something.
Follows the **system appearance** (no in-app theme switch); every token is light/dark
adaptive.

- **Brand accent: `#15B0FF`** (a custom vivid blue, identical in both modes).
  Interactive + selection only (primary buttons, links, the AI radio, the logo) —
  never status, never a decorative fill. System controls (checkboxes, toggles,
  selected tabs) inherit it via the Settings `TabView` tint.
- **Neutrals are native**: text + separators map straight to macOS semantic colors
  (`labelColor` / `secondaryLabelColor` / `tertiaryLabelColor` / `separatorColor`).
  The **page + card fills are hand-tuned** (`#ECECEC`/`#FFFFFF` light,
  `#1E1E1E`/`#2C2C2E` dark) — the system's own window/control colors collide on recent
  macOS and give no card separation, so these reproduce a System Settings pane.
- **Status + identity hues (Flexoki)**: red / amber / green carry CI, review, and the
  mono→amber→red escalation (**red = failure/blocking, amber = caution**); blue /
  purple are per-tab *identity* dots, not status.
- **Tokens, not hex**: `DesignSystem/Color+Flexoki.swift` holds them all
  (`.appAccent`, `.appBackground`, `.appSurface`, `.appHairline`, `.appText`,
  `.appTextSecondary`, `.appTextTertiary`, `.appRed/Amber/Green`, `.appBlue/Purple`).
  Views reference the semantic names — a re-tune touches one file.
- **Effort = neutral gauge** (intensity from the needle, no hue) so the signature
  feature doesn't collide with status colors. **Priority colors only high/urgent**
  (amber/red); low/normal stay quiet since the list is already priority-sorted.
- **Spacing/radius**: `DesignSystem/Layout.swift` holds the scale (hair/tight/snug/
  base/roomy/generous + `cardRadius` 10, `controlRadius` 6). Views use the names.
- **Shared surfaces**: one `.cardSurface(padded:)` modifier (`Components/Surface.swift`)
  builds every card; `InlineStatus`, `TabReorderList`, and `AppIconTile` are shared by
  Settings + onboarding so the two can't drift.
- **Type**: native macOS text styles — a clean built-in hierarchy, no custom sizes.

## Onboarding & Settings
Native, sectioned Settings and a short first-run flow, both on the same surface so
they read as one app.

**Panel** — `MenuBarExtra(.window)`. Backdrop is a **Transparent / Solid** toggle
(Settings → General → Appearance): Transparent makes the host window non-opaque so
content floats over the desktop; Solid is an opaque page. (A frosted-glass option was
tried and dropped.) Header carries a **Refresh** button (spins while fetching) and a
**gear menu** (Preferences ⌘, / About / Quit ⌘Q). The selected tab is white + bold
over a neutral pill — not the accent.

**Settings window** — `Settings` scene (⌘,), a `TabView` of **three** sections on a
solid window surface, sharing `SettingsSection`/`SettingsScaffold`/`.cardSurface`:
- **General** — Appearance (panel background), Startup (launch at login via
  `SMAppService` + auto-refresh interval), Tabs (drag-to-reorder list with a per-tab
  dot + live count + visibility checkbox), Reset MergeMole (red/destructive).
- **Providers** — GitHub (connection card with avatar + scopes, or token entry) and
  AI Triage (three radio cards; Custom model reveals a provider preset + endpoint +
  model + key + Verify).
- **About** — version, build date, links, check-for-updates (UI stub until an updater
  is wired).

**First-run onboarding** — `OnboardingView`, a standalone `Window` (`.hiddenTitleBar`)
that auto-presents at launch until `hasCompletedOnboarding`, then dismisses itself;
brought to front via `NSApp.activate`. **Five steps**: Welcome (brand + a media slot
for a product gif) → Connect GitHub (paste token, verified inline; or Skip for now) →
Choose AI → Personalize (launch-at-login + the shared tab list) → All set (a media slot
for the menu-bar reveal gif). Back / capsule progress dots / primary action along the
bottom; no global "Skip setup". PAT for v1.

**Token safety** — a token is *never* stored unverified. `AppModel.connect` sanitizes
the input (strips whitespace), calls `GitHubAPI.viewerLogin` to verify, and only then
saves to the Keychain. Both Settings and onboarding surface "Connected as *login*" or
the error.

**Persistence** — token + BYO API key via `KeychainSecretStore` (never UserDefaults).
Non-secret prefs are `AppModel` properties backed by UserDefaults (keys in one `Key`
enum): `aiMode`, `byoEndpoint` / `byoModel` / `byoProvider`, `refreshInterval`,
`panelBackground`, `hiddenTabs`, `tabOrder`, `hasCompletedOnboarding`. AppModel is
shared across scenes via `.environment`.

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
