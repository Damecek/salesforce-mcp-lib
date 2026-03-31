#!/usr/bin/env bash
# Run MCP Inspector against the harness
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

"$REPO_ROOT/dev/mcp-harness/inspector/launch.sh" "$@"
