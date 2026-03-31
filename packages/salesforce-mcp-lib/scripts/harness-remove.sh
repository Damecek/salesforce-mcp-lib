#!/usr/bin/env bash
# Remove the development harness from the default scratch org
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Removing MCP development harness classes..."
sf project delete source \
  --source-dir "$(cd "$SCRIPT_DIR/.." && pwd)/dev/mcp-harness/force-app" \
  --target-org "" \
  --no-prompt

echo "Harness removed."
