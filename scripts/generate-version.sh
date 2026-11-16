
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

# Generate ISO week-year.
# Example: week 47 of 2026 = 2647.
MAJOR="$(date -u +%g%V)"

VERSION_PREFIX="${MAJOR}.${MINOR}.${PATCH}-DEV"

echo "Repository: $GITHUB_REPOSITORY"
echo "Version prefix: $VERSION_PREFIX"

# Fetch tags belonging to the calling application repository.
git fetch --force --tags origin

# Find the highest existing DEV build number for this prefix.
LATEST_BUILD="$(
  git tag --list "${VERSION_PREFIX}.*" |
  awk -v prefix="${VERSION_PREFIX}." '
    index($0, prefix) == 1 {
      suffix = substr($0, length(prefix) + 1)
      if (suffix ~ /^[0-9]+$/) {
        print suffix
      }
    }
  ' |
  sort -n |
  tail -n 1
)"

if [[ -z "$LATEST_BUILD" ]]; then
  NEXT_BUILD=1
else
  NEXT_BUILD=$((LATEST_BUILD + 1))
fi

VERSION="${VERSION_PREFIX}.${NEXT_BUILD}"

echo "Generated version: $VERSION"

# Configure Git identity.
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

# Reserve this version in the calling application's repository.
git tag -a "$VERSION" \
  -m "Reserve DEV version $VERSION"

git push origin "refs/tags/$VERSION"

# Return version to the reusable workflow caller.
echo "version=$VERSION" >> "$GITHUB_OUTPUT"

echo "Successfully reserved: $VERSION"
