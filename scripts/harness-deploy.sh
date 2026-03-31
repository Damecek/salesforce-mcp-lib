#!/usr/bin/env bash
# Deploy the development harness to the default scratch org
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Deploying MCP development harness..."
sf project deploy start \
  --source-dir "$REPO_ROOT/dev/mcp-harness/force-app" \
  --wait 10

echo "Harness deployed successfully."
