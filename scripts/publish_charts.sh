
#!/usr/bin/env bash

set -Eeuo pipefail

# --------------------------------------------------
# Required environment variables
# --------------------------------------------------

: "${VERSION:?VERSION is required}"

MODE="${1:-}"

OCI_REGISTRY="${OCI_REGISTRY:-ghcr.io}"
OCI_NAMESPACE="${OCI_NAMESPACE:-impressicotraining/charts}"

# --------------------------------------------------
# Read chart name from Chart.yaml
# --------------------------------------------------

get_chart_name() {
  local chart_yaml="$1/Chart.yaml"

  if [[ ! -f "$chart_yaml" ]]; then
    echo "ERROR: Chart.yaml not found in $1"
    exit 1
  fi

  local name

  name="$(
    sed -nE 's/^name:[[:space:]]*([^[:space:]#]+).*$/\1/p' \
      "$chart_yaml" |
      head -n 1
  )"

  if [[ -z "$name" ]]; then
    echo "ERROR: Unable to read chart name from Chart.yaml"
    exit 1
  fi

  echo "$name"
}

# --------------------------------------------------
# PACKAGE MODE
# --------------------------------------------------

package_chart() {

  : "${CHART_PATH:?CHART_PATH is required}"

  if [[ ! -d "$CHART_PATH" ]]; then
    echo "ERROR: Chart directory not found: $CHART_PATH"
    exit 1
  fi

  CHART_NAME="$(get_chart_name "$CHART_PATH")"

  echo "Chart name: $CHART_NAME"
  echo "Chart version: $VERSION"

  # Validate required files.

  test -f "$CHART_PATH/Chart.yaml"
  test -f "$CHART_PATH/values.yaml"

  # Lint chart before packaging.

  echo "Running Helm lint..."

  helm lint "$CHART_PATH"

  # Package chart.

  mkdir -p chart-package

  echo "Packaging Helm chart..."

  helm package "$CHART_PATH" \
    --version "$VERSION" \
    --app-version "$VERSION" \
    --destination chart-package

  PACKAGE_FILE="chart-package/${CHART_NAME}-${VERSION}.tgz"

  if [[ ! -f "$PACKAGE_FILE" ]]; then
    echo "ERROR: Packaged chart not found: $PACKAGE_FILE"
    exit 1
  fi

  # Export outputs if available.

  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    {
      echo "chart_name=$CHART_NAME"
      echo "chart_file=$PACKAGE_FILE"
    } >> "$GITHUB_OUTPUT"
  fi

  # Summary.

  {
    echo "## Helm Chart Packaging"
    echo ""
    echo "| Field | Value |"
    echo "|---|---|"
    echo "| Chart | $CHART_NAME |"
    echo "| Version | $VERSION |"
    echo "| Package | $PACKAGE_FILE |"
    echo "| Helm Lint | Passed |"
  } >> "${GITHUB_STEP_SUMMARY:-/dev/null}"

  echo "Helm chart packaged successfully."
}

# --------------------------------------------------
# PUBLISH MODE
# --------------------------------------------------

publish_chart() {

  : "${CHART_PACKAGE:?CHART_PACKAGE is required}"
  : "${GHCR_USERNAME:?GHCR_USERNAME is required}"
  : "${GHCR_TOKEN:?GHCR_TOKEN is required}"

  if [[ ! -d "$CHART_PACKAGE" ]]; then
    echo "ERROR: Chart package directory not found."
    exit 1
  fi

  mapfile -t CHART_FILES < <(
    find "$CHART_PACKAGE" -maxdepth 1 -type f -name '*.tgz'
  )

  if [[ "${#CHART_FILES[@]}" -ne 1 ]]; then
    echo "ERROR: Expected exactly one packaged Helm chart."
    exit 1
  fi

  PACKAGE_FILE="${CHART_FILES[0]}"
  PACKAGE_NAME="$(basename "$PACKAGE_FILE" .tgz)"

  EXPECTED_SUFFIX="-${VERSION}"

  if [[ "$PACKAGE_NAME" != *"$EXPECTED_SUFFIX" ]]; then
    echo "ERROR: Chart package version does not match $VERSION."
    exit 1
  fi

  CHART_NAME="${PACKAGE_NAME%"$EXPECTED_SUFFIX"}"

  if [[ -z "$CHART_NAME" ]]; then
    echo "ERROR: Unable to determine chart name."
    exit 1
  fi

  OCI_REPOSITORY="oci://${OCI_REGISTRY}/${OCI_NAMESPACE}"

  echo "Chart name: $CHART_NAME"
  echo "Chart version: $VERSION"
  echo "OCI repository: $OCI_REPOSITORY"

  # Login to GHCR.

  echo "Logging in to GHCR..."

  printf '%s' "$GHCR_TOKEN" | helm registry login "$OCI_REGISTRY" \
    --username "$GHCR_USERNAME" \
    --password-stdin

  # Push chart.

  echo "Publishing Helm chart..."

  helm push "$PACKAGE_FILE" "$OCI_REPOSITORY"

  # Summary.

  {
    echo "## Helm Chart Published"
    echo ""
    echo "| Field | Value |"
    echo "|---|---|"
    echo "| Chart | $CHART_NAME |"
    echo "| Version | $VERSION |"
    echo "| OCI Repository | ${OCI_REGISTRY}/${OCI_NAMESPACE}/${CHART_NAME} |"
    echo "| Status | Published |"
  } >> "${GITHUB_STEP_SUMMARY:-/dev/null}"

  echo "Helm chart published successfully."
  echo "${OCI_REGISTRY}/${OCI_NAMESPACE}/${CHART_NAME}:${VERSION}"
}

# --------------------------------------------------
# Execute requested mode
# --------------------------------------------------

case "$MODE" in
  package)
    package_chart
    ;;

  publish)
    publish_chart
    ;;

  *)
    echo "Usage: $0 {package|publish}"
    exit 1
    ;;
esac
