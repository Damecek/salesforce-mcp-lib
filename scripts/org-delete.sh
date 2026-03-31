#!/usr/bin/env bash
# Delete a scratch org
set -euo pipefail

ALIAS="${1:-mcp-dev}"

echo "Deleting scratch org '${ALIAS}'..."
sf org delete scratch \
  --target-org "${ALIAS}" \
  --no-prompt

echo "Scratch org '${ALIAS}' deleted."

# To clean all expired/unused scratch orgs for the devhub:
#   sf org list --clean --json --target-dev-hub mcp-lib-devhub
