
#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE="${1:?Usage: grype.sh <image-name:tag>}"
REPORT_DIR="${2:-security-reports}"

mkdir -p "$REPORT_DIR"

echo "Scanning image with Grype: $IMAGE"

# Generate JSON report.
grype "$IMAGE" \
  --output json \
  --file "$REPORT_DIR/grype-report.json"

# Fail on HIGH and CRITICAL vulnerabilities.
grype "$IMAGE" --fail-on high
