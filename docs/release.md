# Release

How MergeMole gets built, signed, and shipped to users — and how updates reach them.
This is the plan of record for a process that **isn't fully wired up yet** (the app-side
updater is done; hosting + CI are not); treat the CI half as the target we're building
toward. For what the app *does*, see [app.md](app.md); for what's not built, see
[plan.md](plan.md).

The guiding principle: **you decide the version and write the notes; everything else is
automatic.** No human touches signing, notarization, uploading, or the update feed.

---

## Distribution model: direct download, not the App Store

MergeMole ships as a signed, notarized `.dmg` that users download from the web — not
through the Mac App Store. Direct distribution means **no review gate** and **instant
releases**, and we own the update channel instead of waiting on Apple per release. The
tradeoff we accept is that we host the binary ourselves and run our own updater
([Sparkle](https://sparkle-project.org)) — but because the repo is public, GitHub hosts
everything for free (see below), so there's no cost and little setup.

---

## Repository: public, MIT-licensed

The repo is **public** and licensed **MIT** (see [`LICENSE`](../LICENSE)). The app is free;
open-sourcing it is simple, professional, and — importantly — turns GitHub into our free
public CDN, which removes an entire hosting layer (no S3/R2, no Cloudflare, no DNS
migration). Keeping a future paid/ecosystem play open is still possible via the **open-core**
model: anything monetized later lives in *separate* private repos.

Making the repo public also makes the delivery surfaces free and auth-free:

- **GitHub Releases** — hosts the downloadable `.dmg` at stable public URLs.
- **GitHub Pages** — hosts `appcast.xml` (the Sparkle feed) and `changelog.json` (for the
  website), served at `downloads.mergemole.app` via a CNAME on Porkbun.
- **GitHub Actions** — free and unlimited minutes for public repos; runs the release build.

The app is already pointed at `https://downloads.mergemole.app/appcast.xml` — that host is
GitHub Pages, reached by a single `CNAME downloads → <user>.github.io` record on Porkbun.
Vercel (the marketing site) is untouched.

---

## The two Apple stamps (don't confuse them)

Every release carries two independent signatures. They do different jobs:

1. **Apple Developer ID + notarization** — lets the app *run* on other people's Macs.
   Without it, Gatekeeper blocks the download ("damaged / can't be opened"). Notarization
   is **not review**: it's an automated malware scan (~2–5 min) that staples an "Apple
   checked this" ticket onto the app. Requires the **$99/yr Apple Developer Program** —
   the one unavoidable cost. Notarizing builds is itself free and unlimited.

2. **Sparkle EdDSA signature** — lets the *app* trust that an update actually came from us.
   Generated once with Sparkle's `generate_keys`. The **public key ships inside the app**
   (`SUPublicEDKey` in Info.plist); the **private key never touches the repo** — it lives
   in the local Keychain and as a GitHub Actions secret.

---

## Versioning

Standard SemVer, pragmatic for a solo app:

- **PATCH** (`1.0.1`) — bug fixes, no new UI. Ship freely.
- **MINOR** (`1.1.0`) — new features/settings. The normal cadence.
- **MAJOR** (`2.0.0`) — a redesign or a breaking change to how users configure things.

Two version fields live in the Xcode project (both currently at their `1.0`/`1` defaults):

- `MARKETING_VERSION` — the human version users see (e.g. `1.2.0`).
- `CURRENT_PROJECT_VERSION` — the **build number**, a monotonic integer Sparkle uses to
  decide newer-vs-older. **It must always increase, every release**, even if the marketing
  version is unchanged. This is Sparkle's #1 footgun; the release script owns it so it
  can't drift.

The **git tag** (`v1.2.0`) is a third place the version appears. To keep all three in
lockstep, we never edit them by hand — the release script sets `MARKETING_VERSION`,
increments `CURRENT_PROJECT_VERSION`, and creates the tag from a single typed number.

---

## Release notes

Version *numbers* and release *notes* are separate. Notes are never hardcoded into the
app. They're written per release into the **GitHub Release body**, and the Action fans
that one text to both consumers:

- **Sparkle's in-app "Update Available" window** (via `appcast.xml`)
- **The website changelog** (via `changelog.json` on GitHub Pages)

Write the notes once, they appear in-app and on-site. **Always write them** — Sparkle shows
them in-app on every update, and a blank "what's new" window reads as broken. 3–5
plain-language bullets, benefit-oriented.

---

## Two consumers of the release, one source

Everything a release produces flows from one tagged build:

```
git tag v1.2.0  →  GitHub Action builds & publishes
                         │
      ┌──────────────────┼───────────────────────┐
  the .dmg          appcast.xml            changelog.json
 (GitHub Releases) (GitHub Pages)          (GitHub Pages)
      │                 │                        │
  users download    the app checks          website reads
  & install         this daily              & renders notes
```

- **The app** reads `appcast.xml` from `https://downloads.mergemole.app/appcast.xml`
  (GitHub Pages). Its download links point at the `.dmg` on GitHub Releases.
- **The website** reads `changelog.json` from the same host (a static file behind GitHub's
  CDN; a long `staleTime` in TanStack Query is plenty — it only changes on release).

---

## How Sparkle reaches users

Sparkle is the open-source, free auto-updater standard for non-App-Store Mac apps. In
this app (pure SwiftUI, `MenuBarExtra` + `Settings`, no AppKit menu) it surfaces as a
**"Check for Updates…" button in Settings → About**, plus an automatic check.

- **Automatic check** — a timer, **once every 24 hours** (`SUScheduledCheckInterval =
  86400`). It fires while the app is running (fine — always-on menu-bar app) and checks on
  launch if more than the interval has elapsed. Each check is a single GET to `appcast.xml`.
- **Manual check** — the button; fires one check immediately.
- When a newer version exists and the user accepts, Sparkle downloads the `.dmg`, verifies
  the EdDSA signature, installs, and relaunches.

**v1 Sparkle settings** (all in Info.plist): auto-check **on** by default
(`SUEnableAutomaticChecks`), interval **24h**, plus `SUEnableInstallerLauncherService`
(required because the app is **sandboxed** — see the entitlements below). The app owns
Sparkle's lifetime in `Services/Updater.swift` and drives it from the About tab.

### Sandbox note

The app is sandboxed (`com.apple.security.app-sandbox`). Sparkle-in-a-sandbox needs
`SUEnableInstallerLauncherService = YES` and two mach-lookup temporary-exception
entitlements (`$(PRODUCT_BUNDLE_IDENTIFIER)-spks` / `-spki`), both already set in
[`MergeMole/MergeMole.entitlements`](../MergeMole/MergeMole.entitlements).

---

## Cost

The entire stack is **free except the $99/yr Apple Developer Program.**

| Piece | Tool | Cost |
|---|---|---|
| Source + CI | Public GitHub repo + Actions | Free (unlimited minutes for public repos) |
| Build signing | Apple Developer ID | **$99/yr** (unavoidable) |
| Update framework | Sparkle | Free (embedded library, no service) |
| Binary hosting | GitHub Releases | Free |
| Feed + changelog hosting | GitHub Pages (`downloads.mergemole.app`) | Free |

No bandwidth or storage bills to reason about — GitHub hosts releases and Pages for free
for public repos. The only guaranteed cost is the Apple fee.

---

## What's automatic vs. what you do

### One-time setup (done once, ever)

**App-side (done):**
- Sparkle integrated via SPM; updater + "Check for Updates…" in Settings → About.
- Feed URL + public key + sandbox keys in `Info.plist`; entitlements file wired up.
- Sparkle keypair generated (public key in app, private key in Keychain).

**Still to do:**
1. Make the repo public; enable GitHub Pages; set custom domain `downloads.mergemole.app`.
2. Add the `CNAME downloads → <user>.github.io` record on Porkbun.
3. Paste secrets into GitHub Actions: Apple Developer ID cert (`.p12`) + password,
   notarization credentials (App Store Connect API key or app-specific password), and the
   Sparkle private key. *(No storage/CDN keys — GitHub hosts everything.)*

**Committed to the repo (by us):**
- `release.sh` (the one command you run).
- The GitHub Action (`.github/workflows/…`) that builds, notarizes, and publishes.

### Every release (the repeating loop)

**Normal days:** `git push` to `main` builds and releases **nothing** — it's just saving
code. Push as much as you want.

**Release day — you do exactly two things:**
1. `./release.sh 1.2.0` — sets `MARKETING_VERSION`, bumps `CURRENT_PROJECT_VERSION`,
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
8. Creates the GitHub Release and uploads the .dmg
9. Regenerates appcast.xml on GitHub Pages
10. Writes changelog.json on GitHub Pages
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

1. **Apple Developer Program** — enrolled ✅ (team `TA2LQ3B5QN`).
2. **Sparkle integration** — updater + Settings UI ✅.
3. **Feed URL + public key + sandbox entitlements** — in Info.plist + entitlements ✅.
4. **Go public + GitHub Pages + domain** — flip visibility, enable Pages, custom domain
   `downloads.mergemole.app`, CNAME on Porkbun, branch protection on `main`.
5. **Secrets into GitHub Actions** — Developer ID cert, notarization creds, Sparkle private
   key.
6. **The release Action** — build → notarize → dmg → sign → Release + upload → appcast →
   changelog.
7. **`release.sh`** — the one-command version bump + tag.
8. **Tag `v1.0.0`** — watch the first release flow end to end.

---

## Open decisions

- **CI-on-every-push** — an optional separate workflow that only *compiles* on each push to
  catch breakage, never publishing. Nice-to-have, not needed for v1.
- **Beta channel** — a separate `appcast-beta.xml` for pre-release builds. Deferred.
- **Website "any Mac" copy** — the marketing site says "works on any Mac," but the app
  requires macOS 26.5+ (and on-device AI needs Apple Silicon). Worth reconciling so the
  site and the real requirement don't contradict.
