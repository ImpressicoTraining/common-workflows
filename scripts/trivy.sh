
#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE="${1:?Usage: trivy.sh <image-name:tag>}"
REPORT_DIR="${2:-security-reports}"

mkdir -p "$REPORT_DIR"

echo "Scanning image with Trivy: $IMAGE"

# Generate JSON report.
trivy image \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --format json \
  --output "$REPORT_DIR/trivy-report.json" \
  "$IMAGE"

# Fail on HIGH and CRITICAL vulnerabilities.
trivy image \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --exit-code 1 \
  --format table \
  "$IMAGE"
