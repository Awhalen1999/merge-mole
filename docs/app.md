# MergeMole

A macOS menu-bar app that shows your GitHub pull requests in a panel under the menu-bar
icon — and uses AI to tell you what each PR *is* and what to *prioritize*. It **triages**,
it doesn't just list.

## Why it exists

If you're an active reviewer, you're drowning in PRs. Existing menu-bar PR apps
(PullBar and friends) just dump a list — you still have to open each one to figure out
what matters. MergeMole's bet is that a short AI verdict — a one-line summary, a
priority, and one clause of *why* — turns that list into a ranked work queue you can act
on without context-switching into the browser.

First target user: **an individual developer buried in pull requests.** Team and manager
views come later.

## How it works, end to end

1. **Connect GitHub.** You paste a personal access token (scopes `repo`, `read:org`).
   The token is verified against GitHub *before* it's ever saved, then stored in the
   macOS Keychain — never in plain preferences, and never unverified.
2. **Fetch.** One GraphQL query runs five aliased searches against `:@me` —
   review-requested, assignee, author, mentions, reviewed-by — and merges them into one
   deduped list. Each PR remembers *why* it's there (its "relationships"), plus review
   state, CI status, merge-conflict state, comment count, and line counts.
3. **Triage.** For each PR, the chosen AI engine produces a `Verdict`: a summary, a
   priority, and a short reason. Results are cached to disk, so a PR is only re-evaluated
   when its reviewable content actually changes.
4. **Surface.** The panel shows the PRs sorted by priority. The menu-bar icon carries a
   live count so you know how much is waiting without opening anything.

## The panel

Click the menu-bar icon and a panel drops down. It's always three stacked layers:

- **Header** — the brand mark, a Refresh button (spins while fetching), and a gear menu
  (Preferences ⌘, / About / Quit ⌘Q).
- **Tab bar** — the relationship filter (see Tabs below). Only shown when there's a list
  to filter.
- **Content** — exactly one state at a time: the PR list, a loading skeleton, a
  "caught up" empty state, an error, or — when no token is saved — a **connect screen**
  that links straight into Settings.

The panel backdrop is a user choice (Settings → General → Appearance): **Transparent**
(the window goes non-opaque so content floats over the desktop) or **Solid** (an opaque
page). A frosted-glass option was tried and dropped.

Each PR is a **card**: title, repo, the relationship, status pills (CI, conflicts,
comments), line counts, and — with AI on — the verdict summary and priority. Clicking a
card opens the PR on GitHub. The card branches on a single `VerdictState`
(off / loading / ready / failed) so there's never a half-empty layout or a blank gap.

## Tabs

Tabs are a thin presentation layer over the relationship each PR carries. There's one
tab per relationship, plus an **All** tab that shows everything involving you:

- **All** — every PR across the other tabs (first in the bar, shown by default)
- **Review Requested** — your review is requested
- **Assigned** — assigned to you
- **Created** — you opened it
- **Mentioned** — you're @-mentioned
- **Reviewed** — you've already reviewed it

You control the tab bar in **Settings → General → Tabs**: drag to reorder, uncheck to
hide. By default the bar shows All / Review Requested / Assigned / Created; Mentioned and
Reviewed are noisier and opt-in. (You can't hide the last visible tab — the bar always
has at least one.)

## The menu-bar icon

A custom mole-in-a-burrow template icon: an **empty hole** when nothing's waiting, and a
**mole rising out of it** with the live count beside it when PRs await you. Which groups
feed that count is configurable (Settings → General → Menu-bar count), independent of
which tabs the panel shows; each PR is counted once across the groups you pick.

Because `MenuBarExtra` renders its label monochrome, color escalation can't live in the
menu bar. So the priority tint (amber for high, red for urgent) rides on the
**panel-header count** instead, where SwiftUI color applies.

## AI triage — three modes, one feel

Chosen in Settings → Providers → AI Triage. Whatever you pick, the card reads one
`VerdictState` and branches on it, so the experience is seamless across all three:

1. **On-device (default)** — Apple Foundation Models, running locally. Free, private, no
   key, no data leaves the Mac. If the Mac can't run it, the app falls back to data-only
   cleanly.
2. **Bring your own** — any OpenAI-compatible endpoint, hosted (OpenAI, Anthropic) or
   local (Ollama, LM Studio). You provide a provider preset, endpoint, model, and key,
   then press **Test connection** to confirm it answers.
3. **Off** — no model. Cards collapse cleanly to data-only and you still get a fast,
   organized PR list. This is a first-class mode, not a degraded fallback.

Every verdict shows one clause of *why* — it's auditable, never a black box. The cache
is keyed by engine, so switching modes re-evaluates rather than serving another engine's
output.

## Settings

A native, sectioned Settings window (⌘,) — a `TabView` of three sections on a solid
surface:

- **General** — Appearance (panel background), Behavior (launch at login, auto-refresh
  interval), Tabs (reorder + show/hide), Menu-bar count (which groups feed the badge),
  and Reset (wipes all local data and returns the app to a clean state).
- **Providers** — the GitHub connection card and the AI Triage picker (with the custom-
  model form).
- **About** — version, links, and a check-for-updates control (a UI stub until an updater
  is wired).

## Staying fresh

The app refreshes in the background on an energy-aware schedule
(`NSBackgroundActivityScheduler`), plus on wake and on network return, at an interval you
set. Opening the panel refreshes too, unless it just synced. The Refresh button always
forces a fetch.

## What's deliberately *not* here (v1)

Connectors beyond GitHub (Jira, Linear, Slack), team/lead/manager views,
approve-a-PR-from-the-menu (accidental approvals erode trust), analytics dashboards, and
any paid tier or billing. BYO-key, custom endpoints, and AI-off *are* in scope — they're
core to "use it however you want."

It's **free**: on-device AI and AI-off cost nothing to run, and BYO-key means you cover
your own hosted usage.

---

For the building conventions (color, type, spacing) see [style.md](style.md). For
what's still ahead, see [plan.md](plan.md).
