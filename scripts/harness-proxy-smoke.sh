#!/usr/bin/env bash
set -euo pipefail

SERVER_URL="${SERVER_URL:-$(./scripts/harness-url.sh)}"

if [[ -z "${SF_CLIENT_ID:-}" ]]; then
  cat >&2 <<'EOF'
Missing SF_CLIENT_ID for local client_credentials smoke run.

SF_CLIENT_ID/SF_CLIENT_SECRET are manual prerequisites and are not discoverable from repo state, package metadata, or scratch-org deploy output.
Follow README:
  README.md -> "Manual OAuth App Setup (External Client App)"

Then retry:
  npm run harness:proxy:smoke
EOF
  exit 1
fi

if [[ -z "${SF_CLIENT_SECRET:-}" ]]; then
  cat >&2 <<'EOF'
Missing SF_CLIENT_SECRET for local client_credentials smoke run.

SF_CLIENT_ID/SF_CLIENT_SECRET are manual prerequisites and are not discoverable from repo state, package metadata, or scratch-org deploy output.
Follow README:
  README.md -> "Manual OAuth App Setup (External Client App)"

Then retry:
  npm run harness:proxy:smoke
EOF
  exit 1
fi

SF_MCP_URL="$SERVER_URL" npm run smoke --workspace salesforce-mcp-lib
