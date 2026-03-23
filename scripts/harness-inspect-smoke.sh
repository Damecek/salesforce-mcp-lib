#!/usr/bin/env bash
set -euo pipefail

TARGET_ORG="${TARGET_ORG:-${ORG_ALIAS:-sf-mcp-lib-scratch}}"
INSPECTOR_PROXY_PORT="${INSPECTOR_PROXY_PORT:-6277}"
INSPECTOR_CLIENT_PORT="${INSPECTOR_CLIENT_PORT:-6274}"

pick_port() {
  local preferred_port="$1"

  if ! lsof -nP -iTCP:"$preferred_port" -sTCP:LISTEN >/dev/null 2>&1; then
    printf '%s\n' "$preferred_port"
    return 0
  fi

  node -e '
    const net = require("net");
    const server = net.createServer();
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      if (!address || typeof address === "string") {
        process.stderr.write("Failed to allocate a random port.\n");
        process.exit(1);
      }
      process.stdout.write(String(address.port));
      server.close();
    });
  '
}

INSPECTOR_PROXY_PORT="$(pick_port "$INSPECTOR_PROXY_PORT")"
INSPECTOR_CLIENT_PORT="$(pick_port "$INSPECTOR_CLIENT_PORT")"

SERVER_URL="$(./scripts/harness-url.sh)"
ACCESS_TOKEN="$(./scripts/harness-token.sh)"
ENCODED_SERVER_URL="$(node -e 'process.stdout.write(encodeURIComponent(process.argv[1]))' "$SERVER_URL")"
TMP_DIR="$(mktemp -d)"
INSPECTOR_LOG="$TMP_DIR/inspector.log"
trap '[[ -n "${INSPECTOR_PID:-}" ]] && kill "$INSPECTOR_PID" >/dev/null 2>&1 || true; rm -rf "$TMP_DIR"' EXIT

PORT="$INSPECTOR_PROXY_PORT" \
CLIENT_PORT="$INSPECTOR_CLIENT_PORT" \
DANGEROUSLY_OMIT_AUTH=true \
MCP_AUTO_OPEN_ENABLED=false \
npx -y @modelcontextprotocol/inspector >"$INSPECTOR_LOG" 2>&1 &
INSPECTOR_PID=$!

for _ in $(seq 1 20); do
  if curl -fsS "http://127.0.0.1:${INSPECTOR_PROXY_PORT}/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

SESSION_HEADERS="$TMP_DIR/session.headers"
SESSION_BODY="$TMP_DIR/session.body"

curl -sS -D "$SESSION_HEADERS" -o "$SESSION_BODY" \
  -X POST "http://127.0.0.1:${INSPECTOR_PROXY_PORT}/mcp?transportType=streamable-http&url=${ENCODED_SERVER_URL}" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H 'Accept: application/json, text/event-stream' \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"inspector-proxy-smoke","version":"1.0.0"}}}'

SESSION_ID="$(awk 'BEGIN{IGNORECASE=1} /^mcp-session-id:/ {print $2}' "$SESSION_HEADERS" | tr -d '\r')"
if [[ -z "$SESSION_ID" ]]; then
  echo "Inspector proxy did not return an MCP session id." >&2
  cat "$SESSION_BODY" >&2
  exit 1
fi

run_request() {
  local label="$1"
  local payload="$2"
  local output_file="$TMP_DIR/$(echo "$label" | tr ' /:' '___').out"

  echo "==> $label"
  curl -sS \
    -X POST "http://127.0.0.1:${INSPECTOR_PROXY_PORT}/mcp" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H 'Accept: application/json, text/event-stream' \
    -H 'Content-Type: application/json' \
    -H "mcp-session-id: $SESSION_ID" \
    -d "$payload" | tee "$output_file"
  echo
}

echo "==> initialize"
cat "$SESSION_BODY"
echo

run_request "tools/list" '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
run_request "math.sum" '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"math.sum","arguments":{"a":2,"b":5}}}'
run_request "math.profile_sum" '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"math.profile_sum","arguments":{"profile":{"user":{"id":"user-7","weights":{"primary":4,"secondary":6}},"metadata":{"label":"alpha"}},"bonus":3}}}'
run_request "resources/list" '{"jsonrpc":"2.0","id":5,"method":"resources/list","params":{}}'
run_request "resources/read" '{"jsonrpc":"2.0","id":6,"method":"resources/read","params":{"uri":"mcp://harness/secret/one"}}'
run_request "resources/templates/list" '{"jsonrpc":"2.0","id":7,"method":"resources/templates/list","params":{}}'
run_request "resources/templates/call" '{"jsonrpc":"2.0","id":8,"method":"resources/templates/call","params":{"name":"profile-summary","arguments":{"value":9}}}'
run_request "prompts/list" '{"jsonrpc":"2.0","id":9,"method":"prompts/list","params":{}}'
run_request "prompts/get" '{"jsonrpc":"2.0","id":10,"method":"prompts/get","params":{"name":"review-profile","arguments":{"target":"Acme"}}}'
run_request "negative missing nested field" '{"jsonrpc":"2.0","id":11,"method":"tools/call","params":{"name":"math.profile_sum","arguments":{"profile":{"user":{"id":"broken","weights":{"primary":4}},"metadata":{"label":"alpha"}},"bonus":1}}}'

if ! grep -q '"error"' "$TMP_DIR/negative_missing_nested_field.out"; then
  echo "Expected negative harness call to return an error payload." >&2
  exit 1
fi

echo "Inspector smoke suite completed."
