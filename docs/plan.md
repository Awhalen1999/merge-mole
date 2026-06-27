# Plan

What's not built yet, and roughly how it fits. A direction, not a contract — keep it
current; a stale plan is worse than none.

For what the app *does* today, see [app.md](app.md).

---

## Onboarding (to re-add)

**Status:** removed for the MVP. We cut the first-run wizard to reduce the number of
windows and pieces of persisted state to manage. Today, first run is handled inline:
with no saved token the panel shows its **connect screen**, whose buttons link straight
into Settings, where you can connect GitHub and pick an AI mode. That covers the whole
setup path with zero extra surface.

**Why bring it back:** a guided first run sells the product better than a bare connect
screen — it can explain *why* a token is needed, show the AI choice with context, let
the user personalize their tabs, and end on a "look up at the menu bar" moment. It's a
polish/activation feature, not a correctness one, so it's deferred until the core is
solid.

**Where it fits (technical):**

- **Scene.** Re-add a standalone `Window(id:)` scene in `MergeMoleApp` (the small
  `WindowID` enum comes back with it). Use `.windowStyle(.hiddenTitleBar)`,
  `.windowResizability(.contentSize)`, and `.restorationBehavior(.disabled)`, brought to
  front with `NSApp.activate()`.
- **Auto-present.** Gate it with `.defaultLaunchBehavior(...)`, reading a persisted
  `hasCompletedOnboarding` flag **straight from `UserDefaults`** so the launch decision
  doesn't churn with observable state. (Last time this used `AppModel.onboardedDefaultsKey`
  so the scene and the model read the exact same key.)
- **State.** `AppModel` regains `hasCompletedOnboarding` + `completeOnboarding()` (sets
  the flag and persists it), and `resetAll()` flips it back to `false` and reopens the
  window so a reset replays setup.
- **Reuse, don't rebuild.** The shared components the old flow used were kept on purpose —
  `CustomModelForm`, `RadioCard`, `TabReorderList` / `TabSettingRow`, `InlineStatus`,
  `AppIconTile`, `BrandMark`, `ProminentButtonStyle`, and `.cardSurface`. The wizard is
  mostly chrome (a step container, progress dots, a bottom action bar) wrapping those.
- **Shape.** Five steps: Welcome → Connect GitHub → Choose AI → Personalize (the tab
  list) → All set. Back / progress dots / primary action along the bottom. PAT for v1.

---

## Other things not built yet

- **Test target.** Unit tests over the pure logic: `VerdictInput.signature`,
  `Priority(wire:)`, `SizeBucket`, `PRTab` order-restore + migration, `VerdictCache.prune`,
  `RemoteVerdictEngine.completionsURL`, and the GraphQL merge. These are the
  highest-value tests because they're pure and easy to pin down.
- **App updater.** The About pane's "check for updates" is a UI stub today; wire it to a
  real updater (e.g. Sparkle) or a releases link.

---

## Deferred past v1 (intentionally out of scope)

Tracked here so they don't creep in early:

- **OAuth sign-in** instead of paste-a-token — the main thing deferred past v1.
- **Connectors** beyond GitHub: Jira, Linear, Slack, non-GitHub CI.
- **Team / lead / manager views** — v1 is for the individual reviewer.
- **Approve-a-PR-from-the-menu** — accidental approvals lose trust.
- **Analytics / dashboards.**
- **Paid tier / billing** — the app is free; revisit only if hosted-AI cost ever lands
  on us.

---

## Guiding principles (carry forward)

- Every AI verdict shows one clause of *why*. Auditable, never a black box.
- The PR list works perfectly with AI off — a first-class mode, not a fallback.
- The badge errs toward missing over crying wolf. Start conservative; loosen later.
- Cache hard: re-run a verdict only when the PR's reviewable content changes.
- Secrets live in the Keychain, never `UserDefaults`. Never store a credential unverified.
