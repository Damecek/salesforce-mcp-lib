# CLI Contract: Per-User Salesforce Authentication

**Feature**: 003-per-user-auth | **Date**: 2026-04-07

## Entry Points

The CLI binary (`salesforce-mcp-lib`) supports two modes of operation:

### 1. MCP Server Mode (default, existing + modified)

```
salesforce-mcp-lib [options]
```

Starts the stdio-based MCP proxy server. This is the existing behavior, now with optional per-user auth.

### 2. Login Subcommand (new)

```
salesforce-mcp-lib login [options]
```

Interactive login flow that authenticates the user and stores tokens locally. Does NOT start the MCP server.

## CLI Flags

### MCP Server Mode

| Flag | Env Var | Required | Default | Description |
|------|---------|----------|---------|-------------|
| `--instance-url` | `SF_INSTANCE_URL` | Yes | — | Salesforce instance URL |
| `--client-id` | `SF_CLIENT_ID` | Yes | — | Connected App consumer key |
| `--client-secret` | `SF_CLIENT_SECRET` | **No** ¹ | — | Connected App consumer secret |
| `--endpoint` | `SF_ENDPOINT` | Yes | — | Apex REST endpoint path |
| `--log-level` | `SF_LOG_LEVEL` | No | `info` | Log level (debug\|info\|warn\|error) |
| `--callback-port` | `SF_CALLBACK_PORT` | No | `13338` | Local OAuth callback port |

¹ **Breaking change from v1.0.x**: `--client-secret` / `SF_CLIENT_SECRET` is no longer required. When present, client credentials flow is used (backward compatible). When absent, per-user Authorization Code flow is used.

### Login Subcommand

| Flag | Env Var | Required | Default | Description |
|------|---------|----------|---------|-------------|
| `--instance-url` | `SF_INSTANCE_URL` | Yes | — | Salesforce instance URL |
| `--client-id` | `SF_CLIENT_ID` | Yes | — | Connected App consumer key |
| `--headless` | `SF_HEADLESS` | No | `false` | Print URL instead of opening browser |
| `--callback-port` | `SF_CALLBACK_PORT` | No | `13338` | Local OAuth callback port |
| `--log-level` | `SF_LOG_LEVEL` | No | `info` | Log level |

## Precedence

CLI flags override environment variables (unchanged from v1.0.x).

## Auth Mode Detection

```
client_secret provided?
  ├── Yes → Client Credentials flow (existing behavior, 100% backward compatible)
  └── No  → Per-User Auth flow
              ├── Stored tokens exist and are valid? → Use refresh_token
              └── No stored tokens? → Interactive login (browser or headless)
```

## Usage Examples

### Existing client credentials (unchanged)

```bash
# Via CLI flags
salesforce-mcp-lib \
  --instance-url https://myorg.my.salesforce.com \
  --client-id 3MVG9... \
  --client-secret ABCDEF... \
  --endpoint /services/apexrest/mcp

# Via environment variables
SF_INSTANCE_URL=https://myorg.my.salesforce.com \
SF_CLIENT_ID=3MVG9... \
SF_CLIENT_SECRET=ABCDEF... \
SF_ENDPOINT=/services/apexrest/mcp \
salesforce-mcp-lib
```

### Per-user auth — first-time login

```bash
# Step 1: Login (one-time, interactive)
salesforce-mcp-lib login \
  --instance-url https://myorg.my.salesforce.com \
  --client-id 3MVG9...

# Browser opens → user logs in → tokens stored locally

# Step 2: Start MCP server (uses stored tokens)
salesforce-mcp-lib \
  --instance-url https://myorg.my.salesforce.com \
  --client-id 3MVG9... \
  --endpoint /services/apexrest/mcp
```

### Per-user auth — headless environment

```bash
salesforce-mcp-lib login \
  --instance-url https://myorg.my.salesforce.com \
  --client-id 3MVG9... \
  --headless

# Output to stderr:
#   Please open this URL in a browser to authorize:
#   https://myorg.my.salesforce.com/services/oauth2/authorize?response_type=code&client_id=3MVG9...
#
#   After authorizing, paste the full callback URL or authorization code:
# User pastes → tokens stored
```

### MCP client configuration (Claude Desktop)

```json
{
  "mcpServers": {
    "salesforce": {
      "command": "npx",
      "args": [
        "-y", "salesforce-mcp-lib",
        "--instance-url", "https://myorg.my.salesforce.com",
        "--client-id", "3MVG9...",
        "--endpoint", "/services/apexrest/mcp"
      ]
    }
  }
}
```

Note: No `--client-secret` → per-user auth mode. User must run `login` subcommand first.

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Clean shutdown (stdin closed or login successful) |
| 1 | Configuration error (missing required params) |
| 2 | Authentication failed (invalid credentials, no access, consent denied) |
| 3 | Login timeout (user did not complete OAuth flow within 120 seconds) |

## Stderr Output Contract

All human-readable output goes to stderr (stdout is reserved for JSON-RPC).

### Login Subcommand stderr messages

```
[INFO] Opening browser for Salesforce login...
[INFO] Waiting for authorization at http://localhost:13338/oauth/callback
[INFO] Authorization received. Exchanging code for tokens...
[INFO] Login successful! Tokens stored for myorg.my.salesforce.com
[INFO] User: user@example.com (005xx0000012345)
```

### MCP Server Mode stderr messages (per-user auth)

```
[INFO] salesforce-mcp-lib starting
[INFO]   instance-url : https://myorg.my.salesforce.com
[INFO]   client-id    : 3MVG9...(redacted)
[INFO]   auth-mode    : per-user (authorization code)
[INFO]   endpoint     : /services/apexrest/mcp
[INFO] Loaded stored tokens for myorg.my.salesforce.com
[INFO] Refreshing access token...
[INFO] Token refreshed successfully (user: user@example.com)
[INFO] Listening on stdin for JSON-RPC messages
```

### Error messages (per-user auth)

```
[ERROR] Authentication failed: Your Salesforce credentials were rejected. Try logging in again with: salesforce-mcp-lib login --instance-url ...
[ERROR] Authentication failed: Your Salesforce user does not have access to this Connected App. Contact your Salesforce administrator.
[ERROR] Authentication failed: Cannot reach https://myorg.my.salesforce.com. Check your network connection.
[ERROR] No stored credentials found. Please log in first: salesforce-mcp-lib login --instance-url ... --client-id ...
```
