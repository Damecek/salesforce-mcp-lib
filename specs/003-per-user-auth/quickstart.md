# Quickstart: Per-User Salesforce Authentication

**Feature**: 003-per-user-auth | **Date**: 2026-04-07

## Prerequisites

1. **Salesforce org** with a user account you want to authenticate as
2. **Connected App** configured for OAuth 2.0 Authorization Code flow:
   - OAuth Settings enabled
   - Callback URL: `http://localhost:13338/oauth/callback`
   - Selected OAuth Scopes: `api`, `refresh_token`, `offline_access`
   - "Require Proof Key for Code Exchange (PKCE)" — recommended (the library always uses PKCE)
   - Note the **Consumer Key** (client_id)
3. **Node.js >= 20** installed

## Setup

### Install the package

```bash
npm install -g salesforce-mcp-lib
# or use npx (no install needed)
```

### First-time login

```bash
salesforce-mcp-lib login \
  --instance-url https://myorg.my.salesforce.com \
  --client-id 3MVG9...your_consumer_key
```

A browser window opens → log in to Salesforce → grant access → browser shows "Login successful!"

Tokens are stored locally in `~/.salesforce-mcp-lib/tokens/`.

### Start the MCP server

```bash
salesforce-mcp-lib \
  --instance-url https://myorg.my.salesforce.com \
  --client-id 3MVG9...your_consumer_key \
  --endpoint /services/apexrest/mcp
```

The server starts with your stored credentials. No `--client-secret` needed.

## MCP Client Configuration

### Claude Desktop

Add to `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "salesforce": {
      "command": "npx",
      "args": [
        "-y", "salesforce-mcp-lib",
        "--instance-url", "https://myorg.my.salesforce.com",
        "--client-id", "3MVG9...your_consumer_key",
        "--endpoint", "/services/apexrest/mcp"
      ]
    }
  }
}
```

> **Note**: Run `salesforce-mcp-lib login` first before starting Claude Desktop.

## Headless Environments (SSH, Docker, CI)

```bash
salesforce-mcp-lib login \
  --instance-url https://myorg.my.salesforce.com \
  --client-id 3MVG9... \
  --headless
```

The command prints an authorization URL. Open it in any browser (even on a different machine), authorize, then paste the callback URL back into the terminal.

## Switching Between Modes

### Client Credentials (service account — existing)

When `--client-secret` is provided, the system uses client credentials flow:

```bash
salesforce-mcp-lib \
  --instance-url https://myorg.my.salesforce.com \
  --client-id 3MVG9... \
  --client-secret YOUR_SECRET \
  --endpoint /services/apexrest/mcp
```

### Per-User Auth (individual identity — new)

When `--client-secret` is omitted, the system uses per-user auth:

```bash
salesforce-mcp-lib \
  --instance-url https://myorg.my.salesforce.com \
  --client-id 3MVG9... \
  --endpoint /services/apexrest/mcp
```

The mode is auto-detected. No explicit flag needed.

## Session Management

- **Automatic refresh**: Tokens are refreshed transparently when they expire
- **Session persistence**: Tokens survive across process restarts
- **Session expiry**: If a refresh token is revoked (admin action, password change), you'll be prompted to log in again
- **Switching users**: Delete `~/.salesforce-mcp-lib/tokens/` and run `login` again

## Connected App Setup Guide

1. In Salesforce Setup → App Manager → New Connected App
2. Enable OAuth Settings
3. Set Callback URL: `http://localhost:13338/oauth/callback`
4. Select scopes: `api`, `refresh_token`, `offline_access`
5. Save and note the Consumer Key
6. Under "Manage" → set appropriate policies (e.g., "All users may self-authorize", or assign via permission sets/profiles)

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "No stored credentials found" | Run `salesforce-mcp-lib login` first |
| "Connected App client ID is not recognized" | Verify `--client-id` matches the Consumer Key in Salesforce |
| "User does not have access to this Connected App" | Ask admin to grant access via Connected App policies |
| "Authorization was denied" | Click "Allow" when prompted during login, or retry |
| "Cannot reach instance" | Check network, VPN, and that the instance URL is correct |
| "Session expired and refresh failed" | Password changed or admin revoked access. Run `login` again |
| Port 13338 in use | Use `--callback-port 13339` (and add that callback URL to the Connected App) |
