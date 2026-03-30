# TypeScript Proxy CLI Contract

**Feature**: 001-apex-mcp-server | **Date**: 2026-03-30

This contract defines the TypeScript stdio proxy's command-line interface, configuration, and operational behavior.

---

## CLI Invocation

```bash
npx salesforce-mcp-lib \
  --instance-url https://myorg.my.salesforce.com \
  --client-id <consumer_key> \
  --client-secret <consumer_secret> \
  --endpoint /services/apexrest/mcp/v1
```

### Required Parameters

| Parameter | Env Variable | Description |
|---|---|---|
| `--instance-url` | `SF_INSTANCE_URL` | Salesforce org My Domain URL |
| `--client-id` | `SF_CLIENT_ID` | Connected App consumer key |
| `--client-secret` | `SF_CLIENT_SECRET` | Connected App consumer secret |
| `--endpoint` | `SF_ENDPOINT` | Subscriber's `@RestResource` URL path |

### Optional Parameters

| Parameter | Env Variable | Default | Description |
|---|---|---|---|
| `--log-level` | `SF_LOG_LEVEL` | `info` | Logging verbosity: `debug`, `info`, `warn`, `error` |

**Precedence**: CLI arguments override environment variables.

---

## MCP Client Configuration

### Claude Desktop (`claude_desktop_config.json`)

```json
{
  "mcpServers": {
    "salesforce": {
      "command": "npx",
      "args": [
        "salesforce-mcp-lib",
        "--instance-url", "https://myorg.my.salesforce.com",
        "--client-id", "3MVG9...",
        "--client-secret", "ABC123...",
        "--endpoint", "/services/apexrest/mcp/v1"
      ]
    }
  }
}
```

### MCP Inspector

```bash
npx @modelcontextprotocol/inspector \
  npx salesforce-mcp-lib \
    --instance-url https://myorg.my.salesforce.com \
    --client-id 3MVG9... \
    --client-secret ABC123... \
    --endpoint /services/apexrest/mcp/v1
```

---

## Startup Sequence

1. Parse CLI arguments and environment variables into `BridgeConfig`
2. Validate all required parameters are present (exit with error if missing)
3. Authenticate to Salesforce via OAuth 2.0 client credentials flow
4. Cache the `access_token` and `instance_url`
5. Begin reading JSON-RPC messages from stdin
6. Wait for `initialize` request from the MCP client

---

## Proxy Behavior

### Request Forwarding

For each JSON-RPC message received on stdin:

1. Parse the JSON-RPC message
2. Forward as HTTP POST body to `<instance_url><endpoint>` with `Authorization: Bearer <token>`
3. Receive the HTTP response from Salesforce
4. If HTTP 200 with valid JSON-RPC response: forward to stdout
5. If HTTP 401 (`INVALID_SESSION_ID`): re-authenticate, retry once, then forward result or error
6. If HTTP 500 or non-JSON response: translate to JSON-RPC error (-32603) and forward to stdout

### Session Management (proxy-side)

| Responsibility | Owner |
|---|---|
| Assign `Mcp-Session-Id` | Proxy |
| Track protocol version | Proxy |
| Track negotiated capabilities | Proxy |
| Manage lifecycle state (initializing → operational → closed) | Proxy |
| Validate session state | Proxy |
| Store session state in Salesforce | **Not done** — Apex is stateless |

### Logging

- All log output goes to **stderr** (never stdout — stdout is reserved for JSON-RPC)
- Log levels: `debug`, `info`, `warn`, `error`
- Default level: `info`

| Level | What is logged |
|---|---|
| `debug` | Full JSON-RPC messages, HTTP request/response details, token lifecycle |
| `info` | Startup configuration (redacted secrets), connection events, high-level operations |
| `warn` | Token refresh events, non-fatal errors, unexpected but handled conditions |
| `error` | Authentication failures, Salesforce HTTP errors, proxy-level exceptions |

### Error Translation

| Salesforce Response | Proxy Action |
|---|---|
| HTTP 200, valid JSON-RPC | Forward to stdout unchanged |
| HTTP 401, `INVALID_SESSION_ID` | Re-authenticate via client credentials; retry request once; if retry fails, return JSON-RPC error -32603 |
| HTTP 500, `APEX_ERROR` body | Parse error message; return JSON-RPC error -32603 with Salesforce message |
| HTTP 500, non-JSON body | Return JSON-RPC error -32603 with generic "Salesforce server error" message |
| Network error / timeout | Return JSON-RPC error -32603 with connection error message (no retry) |

---

## Exit Behavior

| Condition | Exit Code | Behavior |
|---|---|---|
| Normal shutdown (stdin EOF) | 0 | Clean exit after processing final response |
| Missing required configuration | 1 | Print usage to stderr, exit immediately |
| Authentication failure at startup | 1 | Print error to stderr, exit immediately |
| Unrecoverable runtime error | 1 | Log error to stderr, exit |
