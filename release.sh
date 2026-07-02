#!/usr/bin/env bash
#
# release.sh — cut a MergeMole release.
#
#   ./release.sh 1.2.0
#
# Sets the marketing version, bumps the build number, commits, creates an
# annotated tag (whose message becomes the release notes shown in-app and on the
# site), and pushes. Pushing the tag is what triggers the release workflow —
# everything after that (build, notarize, dmg, publish) is automatic.
#
# You only ever type the version once, here. The two Xcode version fields and the
# git tag are kept in lockstep so they can't drift.
set -euo pipefail

VERSION="${1:-}"
PBX="MergeMole.xcodeproj/project.pbxproj"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Usage: ./release.sh X.Y.Z   (e.g. ./release.sh 1.2.0)" >&2
  exit 1
fi

# --- Safety checks: clean, on main, in sync, tag free ------------------------
branch="$(git branch --show-current)"
if [[ "$branch" != "main" ]]; then
  echo "Refusing: you're on '$branch', not 'main'." >&2
  exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Refusing: working tree has uncommitted changes." >&2
  exit 1
fi
git fetch --quiet origin main
if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]]; then
  echo "Refusing: local main is not in sync with origin/main." >&2
  exit 1
fi
if git rev-parse "v$VERSION" >/dev/null 2>&1; then
  echo "Refusing: tag v$VERSION already exists." >&2
  exit 1
fi

# --- Bump versions -----------------------------------------------------------
current_build="$(grep -m1 -E 'CURRENT_PROJECT_VERSION = [0-9]+;' "$PBX" | grep -oE '[0-9]+')"
new_build=$((current_build + 1))

# Both target configs (Debug + Release) are updated together.
sed -i '' -E "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = $VERSION;/g" "$PBX"
sed -i '' -E "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = $new_build;/g" "$PBX"

echo "→ MARKETING_VERSION = $VERSION"
echo "→ CURRENT_PROJECT_VERSION = $new_build"

# --- Commit, tag (opens your editor for release notes), push -----------------
git add "$PBX"
git commit -m "Release $VERSION (build $new_build)"

echo
echo "Opening your editor for the release notes — these appear in the in-app"
echo "update window and the website changelog. Use short bullet lines, e.g.:"
echo "    - Faster PR fetching"
echo "    - Fixes a crash when disconnecting GitHub"
echo
git tag -a "v$VERSION"

if [[ -z "$(git tag -l --format='%(contents)' "v$VERSION" | tr -d '[:space:]')" ]]; then
  echo "No release notes entered — aborting and undoing the tag/commit." >&2
  git tag -d "v$VERSION"
  git reset --hard HEAD~1
  exit 1
fi

git push origin main
git push origin "v$VERSION"

echo
echo "✅ Pushed v$VERSION. The release workflow is now building & notarizing."
echo "   Watch it: https://github.com/Awhalen1999/merge-mole/actions"
