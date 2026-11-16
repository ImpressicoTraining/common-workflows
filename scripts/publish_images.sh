
#!/usr/bin/env bash

set -Eeuo pipefail

# --------------------------------------------------
# Required environment variables
# --------------------------------------------------

: "${IMAGE_TAR:?IMAGE_TAR is required}"
: "${LOCAL_IMAGE:?LOCAL_IMAGE is required}"
: "${GHCR_IMAGE:?GHCR_IMAGE is required}"
: "${VERSION:?VERSION is required}"
: "${GHCR_USERNAME:?GHCR_USERNAME is required}"
: "${GHCR_TOKEN:?GHCR_TOKEN is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"

# --------------------------------------------------
# Validate image archive
# --------------------------------------------------

if [[ ! -f "$IMAGE_TAR" ]]; then
  echo "ERROR: Docker image archive not found: $IMAGE_TAR"
  exit 1
fi

echo "Loading Docker image..."

docker load -i "$IMAGE_TAR"

# --------------------------------------------------
# Verify local image
# --------------------------------------------------

LOCAL_TAG="${LOCAL_IMAGE}:${VERSION}"
REMOTE_TAG="${GHCR_IMAGE}:${VERSION}"

docker image inspect "$LOCAL_TAG" >/dev/null

echo "Local image verified: $LOCAL_TAG"

# --------------------------------------------------
# Login to GHCR
# --------------------------------------------------

echo "Logging in to GitHub Container Registry..."

printf '%s' "$GHCR_TOKEN" | docker login ghcr.io \
  --username "$GHCR_USERNAME" \
  --password-stdin

# --------------------------------------------------
# Tag and push image
# --------------------------------------------------

echo "Tagging image..."

docker tag "$LOCAL_TAG" "$REMOTE_TAG"

echo "Pushing image to GHCR..."

PUSH_LOG="${RUNNER_TEMP:-/tmp}/ghcr-push.log"

docker push "$REMOTE_TAG" 2>&1 | tee "$PUSH_LOG"

# --------------------------------------------------
# Extract image digest
# --------------------------------------------------

DIGEST="$(
  grep -oE 'digest: sha256:[a-f0-9]{64}' "$PUSH_LOG" |
  awk '{print $2}' |
  tail -n 1
)"

if [[ ! "$DIGEST" =~ ^sha256:[a-f0-9]{64}$ ]]; then
  echo "ERROR: Unable to extract published image digest."
  exit 1
fi

# --------------------------------------------------
# Export outputs
# --------------------------------------------------

{
  echo "image=$REMOTE_TAG"
  echo "digest=$DIGEST"
  echo "version=$VERSION"
} >> "$GITHUB_OUTPUT"

# --------------------------------------------------
# Summary
# --------------------------------------------------

{
  echo "## Docker Image Published"
  echo ""
  echo "| Field | Value |"
  echo "|---|---|"
  echo "| Local Image | $LOCAL_TAG |"
  echo "| GHCR Image | $REMOTE_TAG |"
  echo "| Digest | $DIGEST |"
  echo "| Version | $VERSION |"
} >> "$GITHUB_STEP_SUMMARY"

echo "Docker image publishing completed successfully."
echo "Published image: $REMOTE_TAG@$DIGEST"
