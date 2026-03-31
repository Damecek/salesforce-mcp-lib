#!/usr/bin/env bash
# Launch MCP Inspector against the development harness
# Usage: ./launch.sh --instance-url <url> --client-id <id> --client-secret <secret>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

npx @modelcontextprotocol/inspector \
  node "$REPO_ROOT/packages/salesforce-mcp-lib/dist/index.js" \
    --endpoint /services/apexrest/mcp/harness \
    "$@"
