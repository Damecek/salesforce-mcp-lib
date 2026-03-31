#!/usr/bin/env bash
# Remove the development harness from the default scratch org
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Removing MCP development harness classes..."
sf project delete source \
  --source-dir "$REPO_ROOT/dev/mcp-harness/force-app" \
  --no-prompt

echo "Harness removed."
