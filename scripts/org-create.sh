#!/usr/bin/env bash
# Create a scratch org for SalesforceMcpLib development
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ALIAS="${1:-mcp-dev}"
DURATION="${2:-7}"

echo "Creating scratch org '${ALIAS}' (${DURATION} days)..."
sf org create scratch \
  --definition-file "${PROJECT_ROOT}/config/project-scratch-def.json" \
  --alias "${ALIAS}" \
  --duration-days "${DURATION}" \
  --set-default \
  --wait 10

echo "Scratch org '${ALIAS}' created successfully."
echo "Pushing source..."
sf project deploy start \
  --source-dir "${PROJECT_ROOT}/force-app" \
  --target-org "${ALIAS}"

echo "Done. Org '${ALIAS}' is ready for development."
