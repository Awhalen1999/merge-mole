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
- [~] 2. Card UI + tab bar, against fake data — working shell exists; needs polish
- [ ] 3. GitHub GraphQL fetch + token in Keychain (real PRs)
- [ ] 4. Cache + re-digest only when the diff actually changes
- [ ] 5. On-device AI: effort tier first, then summary, then priority
- [ ] 6. Icon states (mono → amber → red), then red badge, then one signature polish

## Structure (the seams)
Files are grouped under `MergeMole/` (file-system-synchronized — drop a file in
and Xcode sees it). The point is that Steps 3 and 5 swap implementations, not
rewrite callers:
- `Models/` — `PullRequest`, `Verdict`, `SizeBucket`. Provider-agnostic.
- `Sample/` — `SampleData`: the only fake data. Delete it when real data lands.
- `Services/` — protocols + sample impls:
  - `PRProvider` → `GitHubPRProvider` at Step 3
  - `VerdictEngine` → on-device / BYO engines at Step 5 (AI-off = no engine)
  - `SecretStore` → `KeychainSecretStore` at Step 3
- `State/AppModel` — `@Observable`, the single source of truth. Holds PRs, a
  `VerdictState` per PR, the tab, and the AI mode. Depends only on the protocols.
- `Views/` — `RootView` → `TabBar` + `PRCard`. The card branches on one
  `VerdictState` (`off`/`loading`/`ready`/`failed`) — never three layouts.

Concurrency: target uses approachable concurrency (`SWIFT_DEFAULT_ACTOR_ISOLATION
= MainActor`), so types are main-actor by default; mark real I/O `nonisolated`.

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
