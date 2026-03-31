#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PKG_DIR="$SCRIPT_DIR/../../packages/salesforce-mcp-lib"

# ── defaults (override via env or flags) ─────────────────────────────
INSTANCE_URL="${SF_INSTANCE_URL:-}"
CLIENT_ID="${SF_CLIENT_ID:-}"
CLIENT_SECRET="${SF_CLIENT_SECRET:-}"
ENDPOINT="${SF_ENDPOINT:-/services/apexrest/mcp/e2e}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Starts MCP Inspector connected to the e2e-http-endpoint example.

Options (override env vars SF_INSTANCE_URL, SF_CLIENT_ID, SF_CLIENT_SECRET):
  --instance-url   URL    Salesforce instance URL
  --client-id      KEY    Connected-app consumer key
  --client-secret  SEC    Connected-app consumer secret
  --endpoint       PATH   Apex REST endpoint  [default: /services/apexrest/mcp/e2e]
  -h, --help              Show this help

Example:
  ./run-inspector.sh \\
    --instance-url https://myorg.sandbox.my.salesforce.com \\
    --client-id 3MVG9... \\
    --client-secret B422...
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --instance-url)   INSTANCE_URL="$2";   shift 2 ;;
    --client-id)      CLIENT_ID="$2";      shift 2 ;;
    --client-secret)  CLIENT_SECRET="$2";  shift 2 ;;
    --endpoint)       ENDPOINT="$2";       shift 2 ;;
    -h|--help)        usage ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$INSTANCE_URL" || -z "$CLIENT_ID" || -z "$CLIENT_SECRET" ]]; then
  echo "Error: --instance-url, --client-id, and --client-secret are required." >&2
  echo "       (or set SF_INSTANCE_URL, SF_CLIENT_ID, SF_CLIENT_SECRET env vars)" >&2
  exit 1
fi

# ── build & link locally ──────────────────────────────────────────────
echo "Building salesforce-mcp-lib..."
(cd "$PKG_DIR" && npm run build --silent && npm link --silent 2>/dev/null)

# ── launch inspector ─────────────────────────────────────────────────
echo ""
echo "Starting MCP Inspector..."
echo "  instance-url : $INSTANCE_URL"
echo "  endpoint     : $ENDPOINT"
echo ""

npx @modelcontextprotocol/inspector -- \
  npx salesforce-mcp-lib \
    --instance-url "$INSTANCE_URL" \
    --client-id    "$CLIENT_ID" \
    --client-secret "$CLIENT_SECRET" \
    --endpoint     "$ENDPOINT"
