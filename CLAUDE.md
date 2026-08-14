# CLAUDE.md

Rules for working on MergeMole, a macOS menu-bar app (SwiftUI, macOS 15+).

## Releases

A release happens only when Alex asks for one, and follows these steps in order:

1. Draft the release notes and show them. **Wait for confirmation on the notes.**
2. Run `./release.sh <version>` from a clean, synced `main`. The script owns
   `MARKETING_VERSION`, the build-number bump, and the git tag; never edit those
   by hand. The GitHub Action signs, notarizes, and updates the Sparkle feed.
3. Watch the Action and confirm the release actually shipped.
4. Only then update the README roadmap: check off what shipped. The roadmap is
   never edited outside a release.

No em dashes in release notes or any user-facing copy.

## Feature workflow

- Develop on a branch, one feature per PR. `main` is release-ready.
- Every feature PR includes tests for its logic. Simple but robust: test the
  rules the feature was designed around, not every permutation. No UI or
  snapshot tests.
- Match the codebase's style: heavy doc comments that explain why, not what.

## Testing

- Run with: `xcodebuild test -project MergeMole.xcodeproj -scheme MergeMole -destination 'platform=macOS'`
- Tests are hermetic. No test touches the network, the Keychain, real
  UserDefaults, or anything under `~/Library`. Use the fakes and builders in
  `MergeMoleTests/TestSupport.swift`; `AppModel.init` injects every dependency.
- Every test states a rule of the app. If a test does not encode a behavior a
  user could notice breaking, it does not go in.

## Hard contracts

- `VerdictInput.signature` is the AI verdict-cache key. Changing what feeds it
  invalidates every user's cache and re-runs the AI; a golden test pins it, and
  a prompt change must bump `promptVersion` instead.
- Read/unread state keys on `ReadSignature`, which is deliberately separate
  from `VerdictInput.signature`. Never re-unify them, even though they look
  like duplication.

## Checklists

New user setting:
`Key` enum entry, property with persisting `didSet`, restore in `init`,
reset in `resetAll()`, a `LaunchStateTests` case if init reconciles it.

New unread signal:
`UnreadSignal` case and its component in `ReadSignature`, a row in
`UnreadSignalList`, an entry in `ReadSignatureTests.isolationCases`, a
scenario test if it has special comparison rules.

New GraphQL field:
`PRFields` fragment, `PRNode` decode struct, mapping in `pullRequest(from:)`,
an assert against the fixture in `ProviderDecodeTests`.
