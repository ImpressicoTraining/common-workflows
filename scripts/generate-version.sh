
#!/usr/bin/env bash
set -Eeuo pipefail

MINOR="${1:-0}"
PATCH="${2:-0}"

if [[ ! "$MINOR" =~ ^[0-9]+$ || ! "$PATCH" =~ ^[0-9]+$ ]]; then
  echo "ERROR: MINOR and PATCH must be numeric."
  exit 1
fi

if [[ -z "${GITHUB_OUTPUT:-}" ]]; then
  echo "ERROR: GITHUB_OUTPUT is not available."
  exit 1
fi

# ISO week-year: for example, week 47 of 2026 = 2647.
MAJOR="$(date -u +%g%V)"

VERSION_PREFIX="${MAJOR}.${MINOR}.${PATCH}-DEV"

echo "Fetching existing Git tags..."
git fetch --force --tags origin

# Find the highest existing DEV build number for this version.
LATEST_BUILD="$(
  git tag --list "${VERSION_PREFIX}.*" |
  grep -E "^${VERSION_PREFIX//./\\.}\.[0-9]+$" |
  sed -E 's/.*\.([0-9]+)$/\1/' |
  sort -n |
  tail -n 1 || true
)"

if [[ -z "$LATEST_BUILD" ]]; then
  NEXT_BUILD=1
else
  NEXT_BUILD=$((LATEST_BUILD + 1))
fi

VERSION="${VERSION_PREFIX}.${NEXT_BUILD}"

echo "Next DEV version: $VERSION"

# Reserve the version immediately to avoid reusing it after a failed build.
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

git tag -a "$VERSION" -m "Reserve DEV version $VERSION"
git push origin "refs/tags/$VERSION"

echo "version=$VERSION" >> "$GITHUB_OUTPUT"

echo "Reserved version: $VERSION"
