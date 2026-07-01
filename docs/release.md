# Release

How MergeMole gets built, signed, and shipped to users — and how updates reach them.
This is the plan of record for a process that **isn't wired up yet**; treat it as the
target we're building toward. For what the app *does*, see [app.md](app.md); for what's
not built, see [plan.md](plan.md).

The guiding principle: **you decide the version and write the notes; everything else is
automatic.** No human touches signing, notarization, uploading, or the update feed.

---

## Distribution model: direct download, not the App Store

MergeMole ships as a signed, notarized `.dmg` that users download from the web — not
through the Mac App Store. The App Store would force sandboxing, which fights everything
this app does: it reads local git state via `gh`/GitHub's API, talks to user-configured
AI endpoints (the BYO connection), and lives in the menu bar. Direct distribution also
means **no review gate** and **instant releases** — we own the update channel instead of
waiting on Apple per release.

The tradeoff we accept: we host the binary ourselves and run our own updater. That's
Cloudflare R2 + [Sparkle](https://sparkle-project.org), both covered below, both free at
our scale.

---

## Repository: private source, public binaries

The repo stays **private**. The app is free, but keeping source closed preserves the
option to build a paid ecosystem around it later (open-sourcing is a one-way door). No
`LICENSE` file — absence of one means "all rights reserved," which is the protection we
want. (A user-facing **EULA** is a separate, tiny thing we can add later; not a code
license, not blocking v1.)

Because the repo is private, its GitHub Release *assets* would require an auth token to
download — a non-starter for an updater that can't carry secrets. So the split is:

- **GitHub (private repo)** — source of truth for code + CI. This is where the build robot
  (GitHub Actions) runs.
- **Cloudflare R2 (public bucket)** — where the downloadable `.dmg`, the update feed, and
  the website changelog live. Served from `downloads.mergemole.app`. Public-read, no auth.

R2 is chosen over S3 for one reason: **egress (bandwidth) is free.** Users downloading
updates never costs us anything, no matter how many or how large. R2's metered resources
(storage, read operations) stay inside the free tier until hundreds of thousands of daily
users — see [Cost](#cost) below.

---

## The two Apple stamps (don't confuse them)

Every release carries two independent signatures. They do different jobs:

1. **Apple Developer ID + notarization** — lets the app *run* on other people's Macs.
   Without it, Gatekeeper blocks the download ("damaged / can't be opened" on modern
   macOS, where the right-click bypass is being removed). Notarization is **not review**:
   it's an automated malware scan (~2–5 min) that staples an "Apple checked this" ticket
   onto the app. It never rejects for content or features. Requires the **$99/yr Apple
   Developer Program** — the one unavoidable cost in this whole stack. Notarizing builds
   is itself free and unlimited.

2. **Sparkle EdDSA signature** — lets the *app* trust that an update actually came from us.
   Generated once with Sparkle's `generate_keys` tool. The **public key ships inside the
   app**; the **private key never touches the repo** — it lives in the local Keychain and
   as a GitHub Actions secret.

---

## Versioning

Standard SemVer, pragmatic for a solo app:

- **PATCH** (`1.0.1`) — bug fixes, no new UI. Ship freely.
- **MINOR** (`1.1.0`) — new features/settings. The normal cadence.
- **MAJOR** (`2.0.0`) — a redesign or a breaking change to how users configure things.

Two version fields live in the Xcode project (both currently at their `1.0`/`1` defaults):

- `MARKETING_VERSION` — the human version users see (e.g. `1.2.0`). Sparkle compares this
  loosely.
- `CURRENT_PROJECT_VERSION` — the **build number**, a monotonic integer Sparkle uses to
  decide newer-vs-older. **It must always increase, every single release**, even if the
  marketing version is unchanged. This is Sparkle's #1 footgun; the release script owns it
  so it can't drift.

The **git tag** (`v1.2.0`) is a third place the version appears. To keep all three in
lockstep, we never edit them by hand — the release script sets `MARKETING_VERSION`,
increments `CURRENT_PROJECT_VERSION`, and creates the tag from a single typed number.

---

## Release notes

Version *numbers* and release *notes* are separate. Notes are never hardcoded into the
app. They're written per release into the **GitHub Release body**, and the Action fans
that one text to both consumers:

- **Sparkle's in-app "Update Available" window** (via `appcast.xml`)
- **The website changelog** (via `changelog.json` on R2)

Write the notes once, they appear in-app and on-site. **Always write them** — even if we
didn't have a public changelog page, Sparkle shows them in-app on every update, and a
blank "what's new" window reads as broken. 3–5 plain-language bullets, benefit-oriented.

---

## Two consumers of the release, one source

Everything a release produces flows from one tagged build:

```
git tag v1.2.0  →  GitHub Action builds & publishes
                         │
      ┌──────────────────┼──────────────────┐
  appcast.xml       the .dmg           changelog.json
  (Sparkle feed)  (the download)    (website changelog)
      │                 │                   │
   the app checks    users download     website reads
   this daily        & install          & renders notes
```

- **The app** reads `appcast.xml` from `https://downloads.mergemole.app/appcast.xml`.
- **The website** reads `changelog.json` from R2 (a static file behind Cloudflare's CDN;
  a long `staleTime` in TanStack Query is plenty — it only changes on release).

---

## How Sparkle reaches users

Sparkle is the open-source, free auto-updater standard for non-App-Store Mac apps. In
this app (pure SwiftUI, `MenuBarExtra` + `Settings`, no AppKit menu) it surfaces as a
**"Check for Updates…" button in the panel and in Settings**, plus an automatic check.

- **Automatic check** — a timer, default **once every 24 hours** (`SUScheduledCheckInterval
  = 86400`; minimum allowed is 1h). It only fires while the app is running (fine — this is
  an always-on menu-bar app) and checks on launch if more than the interval has elapsed.
  Each check is a single GET to `appcast.xml`.
- **Manual check** — the button; fires one check immediately.
- When a newer version exists and the user accepts, Sparkle downloads the `.dmg`, verifies
  the EdDSA signature, installs, and relaunches.

**v1 Sparkle settings:** auto-check **on** by default (user can toggle off — Sparkle
provides that UI), interval **24h**, automatic-download **off** (prompt the user; less
surprising while the pipeline is young), manual "Check for Updates…" always present.

---

## Cost

The entire stack is **free except the $99/yr Apple Developer Program.**

| Piece | Tool | Cost |
|---|---|---|
| Source + CI | Private GitHub repo + Actions | Free (2,000 build-min/mo; a build is ~5–10 min) |
| Build signing | Apple Developer ID | **$99/yr** (unavoidable) |
| Update framework | Sparkle | Free (embedded library, no service) |
| Binary + feed hosting | Cloudflare R2 + `downloads.mergemole.app` | Free tier |
| Website changelog | `changelog.json` on R2 | Free |

R2 free-tier math, so we know when "free" ends:

- **Egress/bandwidth:** unlimited, free — DMG downloads never cost us.
- **Reads (the binding limit):** 10M GETs/month. One user checking daily ≈ 30 GETs/month →
  **~333,000 daily-active users** before it matters.
- **Storage:** 10 GB free; a DMG is ~5–20 MB and we keep only the last several versions →
  well under 1 GB.

Realistically: we never pay Cloudflare. The only guaranteed cost is the Apple fee.

---

## What's automatic vs. what you do

### One-time setup (done once, ever)

**You:**
1. Add Sparkle to the app in Xcode (File → Add Package Dependencies → the Sparkle repo).
2. Run Sparkle's `generate_keys` once → public key into the app, private key into Keychain.
3. Create the R2 bucket in Cloudflare, wire it to `downloads.mergemole.app` (public-read).
4. Paste secrets into GitHub Actions: Apple Developer ID cert (`.p12`), Sparkle private
   key, R2 access keys.

**Claude/code (committed to the repo):**
- Sparkle updater controller + "Check for Updates…" button.
- Feed URL + public key wired into the app's Info.plist build settings.
- `release.sh` (the one command you run).
- The GitHub Action (`.github/workflows/…`) that builds and ships.

### Every release (the repeating loop)

**Normal days:** `git push` to `main` builds and releases **nothing** — it's just saving
code. Push as much as you want.

**Release day — you do exactly two things:**
1. `./release.sh 1.2.0` — this sets `MARKETING_VERSION`, bumps `CURRENT_PROJECT_VERSION`,
   commits, tags `v1.2.0`, and pushes the tag.
2. Write the release notes (in the script prompt, or by editing the GitHub Release after).

**Then the Action does all of this automatically:**
```
1. Checks out the tagged code
2. Builds the .app
3. Signs it (Developer ID)
4. Notarizes it with Apple + waits for the ticket
5. Staples the ticket onto it
6. Packages it into a .dmg
7. Signs the .dmg with the Sparkle key
8. Uploads the .dmg to R2
9. Regenerates appcast.xml on R2
10. Writes changelog.json on R2
11. Creates the GitHub Release with your notes
```
~5–10 minutes later the version is live. **Users' apps** notice via the appcast and update
themselves; **the website** changelog updates itself. You do nothing further.

### The only things you ever track by hand
- **The version number** (typed once into `release.sh`).
- **The release notes** (a few bullets).

Everything else — build numbers, signing, notarization, uploading, the update feed, the
website changelog — is automatic.

---

## Build order (what to wire, in dependency order)

Nothing is wired yet. Each step unblocks the next:

1. **Apple Developer Program** — enrolled ✅ (team `TA2LQ3B5QN`).
2. **Sparkle integration** — add via SPM; updater controller + "Check for Updates…" button;
   feed URL + public key into build settings. *(The long pole — everything downstream needs
   this.)*
3. **Sparkle keypair** — `generate_keys`; public key → app, private key → Keychain + GH
   secret.
4. **R2 bucket + custom domain** — `downloads.mergemole.app`, public-read.
5. **Secrets into GitHub Actions** — Developer ID cert, Sparkle private key, R2 keys.
6. **The release Action** — build → notarize → dmg → sign → upload → appcast → changelog.
7. **`release.sh`** — the one-command version bump + tag.
8. **Tag `v1.0.0`** — watch the first release flow end to end.

---

## Open decisions

- **"Check for Updates…" placement** — panel footer, Settings, or both. Leaning **both**
  (footer for discoverability, Settings for the auto-check toggle).
- **CI-on-every-push** — an optional separate workflow that only *compiles* on each push to
  catch breakage, never touching R2. Nice-to-have, not needed for v1.
- **Beta channel** — a separate `appcast-beta.xml` for pre-release builds. Deferred.
- **EULA** — end-user terms; add before/around public launch.
