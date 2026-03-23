#!/usr/bin/env bash
set -euo pipefail

SERVER_URL="${SERVER_URL:-$(./scripts/harness-url.sh)}"

if [[ -z "${SF_CLIENT_ID:-}" ]]; then
  echo "SF_CLIENT_ID is required for client_credentials smoke runs." >&2
  exit 1
fi

if [[ -z "${SF_CLIENT_SECRET:-}" ]]; then
  echo "SF_CLIENT_SECRET is required for client_credentials smoke runs." >&2
  exit 1
fi

SF_MCP_URL="$SERVER_URL" npm run smoke --workspace salesforce-mcp-lib
