
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

echo "Repository: ${GITHUB_REPOSITORY:-unknown}"

# ISO week-year.
MAJOR="$(date -u +%g%V)"
VERSION_PREFIX="${MAJOR}.${MINOR}.${PATCH}-DEV"

echo "Version prefix: $VERSION_PREFIX"

# Fetch existing tags.
git fetch --force --tags origin

# Find the latest build number.
LATEST_BUILD="$(
  git tag --list "${VERSION_PREFIX}.*" |
  awk -v prefix="${VERSION_PREFIX}." '
    index($0, prefix) == 1 {
      suffix = substr($0, length(prefix) + 1)
      if (suffix ~ /^[0-9]+$/) print suffix
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

# Export version for subsequent jobs.
echo "version=$VERSION" >> "$GITHUB_OUTPUT"

echo "Version generated successfully."
echo "Tag creation will happen after Main workflow succeeds."
