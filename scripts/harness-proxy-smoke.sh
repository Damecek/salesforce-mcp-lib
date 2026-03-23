#!/usr/bin/env bash
set -euo pipefail

SERVER_URL="${SERVER_URL:-$(./scripts/harness-url.sh)}"

if [[ -z "${SF_CLIENT_ID:-}" ]]; then
  cat >&2 <<'EOF'
Missing SF_CLIENT_ID for local client_credentials smoke run.

This value is not discoverable from repo state or scratch-org deploy output.
Manual local step:
1. Open the External Client App in the target Salesforce org.
2. Retrieve the consumer key and consumer secret from OAuth settings.
3. Export them locally:
   export SF_CLIENT_ID='your-consumer-key'
   export SF_CLIENT_SECRET='your-consumer-secret'

Then retry:
  npm run harness:proxy:smoke
EOF
  exit 1
fi

if [[ -z "${SF_CLIENT_SECRET:-}" ]]; then
  cat >&2 <<'EOF'
Missing SF_CLIENT_SECRET for local client_credentials smoke run.

This value is not discoverable from repo state or scratch-org deploy output.
Manual local step:
1. Open the External Client App in the target Salesforce org.
2. Retrieve the consumer key and consumer secret from OAuth settings.
3. Export them locally:
   export SF_CLIENT_ID='your-consumer-key'
   export SF_CLIENT_SECRET='your-consumer-secret'

Then retry:
  npm run harness:proxy:smoke
EOF
  exit 1
fi

SF_MCP_URL="$SERVER_URL" npm run smoke --workspace salesforce-mcp-lib
