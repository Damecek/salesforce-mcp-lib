#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI_ENTRY="${REPO_ROOT}/packages/salesforce-mcp-lib/dist/index.js"
SERVER_NAME="${CODEX_MCP_SERVER_NAME:-salesforce-opportunity-smoke-$$}"
SERVER_URL="${SF_MCP_URL:-https://carvago--devas.sandbox.my.salesforce.com/services/apexrest/mcp/opportunity/}"
EXPECTED_TOOL_NAME="${EXPECTED_TOOL_NAME:-opportunity.fetch_with_assets}"
NORMALIZED_EXPECTED_TOOL_NAME="$(printf '%s' "$EXPECTED_TOOL_NAME" | tr '.-' '__')"

if [[ ! -f "$CLI_ENTRY" ]]; then
  echo "Missing built CLI entry at ${CLI_ENTRY}. Run: npm run build --workspace salesforce-mcp-lib" >&2
  exit 1
fi

if [[ -z "${SF_CLIENT_ID:-}" ]]; then
  cat >&2 <<'EOF'
Missing SF_CLIENT_ID for local Codex MCP smoke run.

SF_CLIENT_ID/SF_CLIENT_SECRET are manual prerequisites and are not discoverable from repo state, package metadata, or scratch-org deploy output.
Follow README:
  README.md -> "Manual OAuth App Setup (External Client App)"

Then retry:
  npm run codex:mcp:smoke
EOF
  exit 1
fi

if [[ -z "${SF_CLIENT_SECRET:-}" ]]; then
  cat >&2 <<'EOF'
Missing SF_CLIENT_SECRET for local Codex MCP smoke run.

SF_CLIENT_ID/SF_CLIENT_SECRET are manual prerequisites and are not discoverable from repo state, package metadata, or scratch-org deploy output.
Follow README:
  README.md -> "Manual OAuth App Setup (External Client App)"

Then retry:
  npm run codex:mcp:smoke
EOF
  exit 1
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  codex mcp remove "$SERVER_NAME" >/dev/null 2>&1 || true
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

OUTPUT_FILE="$TMP_DIR/last-message.txt"
LOG_FILE="$TMP_DIR/codex-exec.log"
CODEX_PROMPT="${CODEX_PROMPT:-Use the ${SERVER_NAME} MCP server. Call tools/list and report only the list of available tool names, preserving the tool names exactly.}"

codex mcp add "$SERVER_NAME" \
  --env "SF_CLIENT_ID=${SF_CLIENT_ID}" \
  --env "SF_CLIENT_SECRET=${SF_CLIENT_SECRET}" \
  -- node "$CLI_ENTRY" --url "$SERVER_URL" >/dev/null

codex exec \
  --ephemeral \
  --sandbox read-only \
  -C "$REPO_ROOT" \
  -o "$OUTPUT_FILE" \
  "$CODEX_PROMPT" >"$LOG_FILE" 2>&1 || {
    cat "$LOG_FILE" >&2
    exit 1
  }

if [[ ! -s "$OUTPUT_FILE" ]]; then
  cat "$LOG_FILE" >&2
  echo "Codex exec produced no final message." >&2
  exit 1
fi

cat "$OUTPUT_FILE"

if ! grep -Fq "$EXPECTED_TOOL_NAME" "$OUTPUT_FILE" && ! grep -Fq "$NORMALIZED_EXPECTED_TOOL_NAME" "$OUTPUT_FILE"; then
  cat "$LOG_FILE" >&2
  echo "Expected tool name not found in Codex output: ${EXPECTED_TOOL_NAME}" >&2
  exit 1
fi
