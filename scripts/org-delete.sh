#!/usr/bin/env bash
# Delete a scratch org
set -euo pipefail

ALIAS="${1:-mcp-dev}"

echo "Deleting scratch org '${ALIAS}'..."
sf org delete scratch \
  --target-org "${ALIAS}" \
  --no-prompt

echo "Scratch org '${ALIAS}' deleted."
