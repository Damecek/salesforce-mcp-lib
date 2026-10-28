#!/usr/bin/env bash
# Create a scratch org for SalesforceMcpLib development (lifetime: 1 day)
# Usage: ./org-create.sh [alias] [--target-dev-hub <alias-or-username>]
#        SF_DEVHUB=<alias-or-username> ./org-create.sh [alias]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ALIAS="mcp-dev"
DEVHUB="${SF_DEVHUB:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-dev-hub) DEVHUB="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; exit 1 ;;
    *) ALIAS="$1"; shift ;;
  esac
done
if [[ -z "$DEVHUB" ]]; then
  echo "Error: no Dev Hub given. Use --target-dev-hub or set SF_DEVHUB." >&2
  exit 1
fi

echo "Creating scratch org '${ALIAS}' (1 day, devhub: ${DEVHUB})..."
sf org create scratch \
  --definition-file "${PROJECT_ROOT}/config/project-scratch-def.json" \
  --alias "${ALIAS}" \
  --target-dev-hub "${DEVHUB}" \
  --duration-days 1 \
  --set-default \
  --wait 10

echo "Scratch org '${ALIAS}' created successfully."
echo "Pushing source..."
sf project deploy start \
  --source-dir "${PROJECT_ROOT}/force-app" \
  --target-org "${ALIAS}"

echo "Done. Org '${ALIAS}' is ready for development."
