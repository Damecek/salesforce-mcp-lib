# Quickstart: Per-User Salesforce Authentication

**Feature**: 003-per-user-auth | **Date**: 2026-04-07

## Prerequisites

1. **Salesforce org** with a user account you want to authenticate as
2. **External Client App** (or Connected App) configured for OAuth 2.0 Authorization Code flow — see [Salesforce Setup](#1-salesforce-setup-external-client-app) below
3. **Node.js >= 20** installed

---

## 1. Salesforce Setup: External Client App

An **External Client App** is the recommended way to configure OAuth in Salesforce (API v60+). If your org doesn't have External Client App Manager, use a classic Connected App — see [Alternative: Connected App Setup](#alternative-connected-app-setup).

### Step-by-step

1. **Navigate**: Setup → Apps → App Manager → **External Client App Manager** → **New External Client App**
2. **Basic Info**:
   - **External Client App Name**: `MCP Bridge` (or any descriptive name)
   - **Contact Email**: your admin email
   - **Distribution State**: Local
3. **Create** the app, then open it
4. **Add OAuth Flow**: In the app detail page → **OAuth Settings** section → **Add Consumer**:
   - **Flow**: Select **Authorization Code and Credentials Flow** (or "Authorization Code (PKCE)" if listed separately)
   - **Enable PKCE**: Yes / Required *(the library always sends PKCE — this enforces it server-side)*
   - **Callback URL**: `http://localhost:13338/oauth/callback`
   - **Selected OAuth Scopes**:
     - `Manage user data via APIs (api)`
     - `Perform requests at any time (refresh_token, offline_access)`
   - **Require Secret for Web Server Flow**: **No** *(PKCE replaces the client secret)*
5. **Save** and note the **Consumer Key** (this is your `client_id`)
6. **User Access Policy**: In the app → **Policies** → **Manage Policies**:
   - **Permitted Users**: `All users may self-authorize` *(simplest)*, or restrict via Profiles/Permission Sets
   - **IP Relaxation**: `Relax IP restrictions` *(recommended for CLI use from developer machines)*
   - **Refresh Token Policy**: `Refresh token is valid until revoked` *(recommended for persistent sessions)*

### What you'll need from this step

| Value | Where to find it | Example |
|-------|-------------------|---------|
| **Consumer Key** (client_id) | External Client App → OAuth Settings → Consumer Key | `3MVG9fTLmJ60pJ5L...` |
| **Instance URL** | Your Salesforce org URL | `https://myorg.my.salesforce.com` |
| **Endpoint** | Your Apex REST endpoint path | `/services/apexrest/mcp/records` |

### Alternative: Connected App Setup

If your org uses the classic Connected App model:

1. Setup → App Manager → **New Connected App**
2. **Enable OAuth Settings**: checked
3. **Callback URL**: `http://localhost:13338/oauth/callback`
4. **Selected OAuth Scopes**: `api`, `refresh_token`, `offline_access`
5. **Require Proof Key for Code Exchange (PKCE)**: checked
6. **Require Secret for Web Server Flow**: unchecked
7. Save → note the **Consumer Key**
8. Manage → set IP Relaxation and Permitted Users as above

---

## 2. First-Time Login

Before the MCP server can operate in per-user mode, you need to authenticate once:

```bash
npx salesforce-mcp-lib login \
  --instance-url https://myorg.my.salesforce.com \
  --client-id 3MVG9...your_consumer_key
```

**What happens**:
1. A browser window opens → Salesforce login page
2. You log in with your Salesforce credentials
3. You grant access to the External Client App ("Allow")
4. Browser shows "Login successful! You can close this tab."
5. Tokens are stored locally in `~/.salesforce-mcp-lib/tokens/`

After this one-time login, the MCP server uses your stored tokens. Sessions persist across restarts via automatic token refresh.

---

## 3. MCP Client Configuration

### Claude Code / Claude CLI (recommended)

The standard way to use MCP servers with Claude Code:

**Step 1**: Log in (one-time, in your terminal):

```bash
npx salesforce-mcp-lib login \
  --instance-url https://myorg.my.salesforce.com \
  --client-id 3MVG9...your_consumer_key
```

**Step 2**: Add the MCP server to Claude Code:

Open Claude Code → type `/mcp` → **Add Server** → **stdio** → enter:

- **Name**: `salesforce`
- **Command**: `npx -y salesforce-mcp-lib --instance-url https://myorg.my.salesforce.com --client-id 3MVG9...your_consumer_key --sf-endpoint /services/apexrest/mcp/records`

Or manually edit `~/.claude.json`:

```json
{
  "mcpServers": {
    "salesforce": {
      "command": "npx",
      "args": [
        "-y", "salesforce-mcp-lib",
        "--instance-url", "https://myorg.my.salesforce.com",
        "--client-id", "3MVG9...your_consumer_key",
        "--sf-endpoint", "/services/apexrest/mcp/records"
      ]
    }
  }
}
```

**Step 3**: Verify in Claude Code:

1. Open Claude Code
2. Type `/mcp`
3. Select the **salesforce** server → verify status is **connected**
4. If status shows an auth error → re-run `npx salesforce-mcp-lib login ...` in your terminal, then restart the server from `/mcp`

**Auth re-authorization flow** (when tokens expire or are revoked):

1. In Claude Code → `/mcp` → select **salesforce** server
2. If the server shows a connection error (session expired, token revoked)
3. Open your terminal → run `npx salesforce-mcp-lib login --instance-url ... --client-id ...`
4. Complete the browser auth flow
5. Back in Claude Code → `/mcp` → select **salesforce** → **Restart**

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
        "--sf-endpoint", "/services/apexrest/mcp/records"
      ]
    }
  }
}
```

> **Note**: Run `npx salesforce-mcp-lib login` first before starting Claude Desktop.

### Other MCP Clients

Any MCP client that supports stdio transport can use the server. The pattern is always:

1. Run `login` subcommand once to authenticate
2. Configure the MCP client to run `npx salesforce-mcp-lib` with `--instance-url`, `--client-id`, and `--sf-endpoint`
3. No `--client-secret` needed — per-user auth is auto-detected

---

## 4. Testing with a Real Org

### Test configuration (Carvago org)

```bash
# Step 1: Login
npx salesforce-mcp-lib login \
  --instance-url https://carvago.my.salesforce.com \
  --client-id 3MVG9fTLmJ60pJ5LtEXrrYU_yvTMZwYXbrMNq0Nj0Dsk2snkXq4LZYtyJx7ACykA_qWQhBMIdudcm.h7xCuOs

# Step 2: Start MCP server (for manual testing)
npx salesforce-mcp-lib \
  --instance-url https://carvago.my.salesforce.com \
  --client-id 3MVG9fTLmJ60pJ5LtEXrrYU_yvTMZwYXbrMNq0Nj0Dsk2snkXq4LZYtyJx7ACykA_qWQhBMIdudcm.h7xCuOs \
  --sf-endpoint /services/apexrest/mcp/records
```

### Claude Code test configuration

```json
{
  "mcpServers": {
    "salesforce": {
      "command": "npx",
      "args": [
        "-y", "salesforce-mcp-lib",
        "--instance-url", "https://carvago.my.salesforce.com",
        "--client-id", "3MVG9fTLmJ60pJ5LtEXrrYU_yvTMZwYXbrMNq0Nj0Dsk2snkXq4LZYtyJx7ACykA_qWQhBMIdudcm.h7xCuOs",
        "--sf-endpoint", "/services/apexrest/mcp/records"
      ]
    }
  }
}
```

### Verification checklist

- [ ] `login` command opens browser and completes OAuth flow
- [ ] Tokens are stored in `~/.salesforce-mcp-lib/tokens/`
- [ ] MCP server starts without prompting for login again
- [ ] Claude Code `/mcp` shows the server as connected
- [ ] Claude can discover and invoke Salesforce tools through the server
- [ ] After restarting Claude Code, the server reconnects without re-login
- [ ] In Salesforce Setup → Login History: requests appear under your user (not a service account)

---

## 5. Switching Between Auth Modes

### Client Credentials (service account — existing behavior)

When `--client-secret` is provided, the system uses client credentials flow (backward compatible):

```bash
npx salesforce-mcp-lib \
  --instance-url https://myorg.my.salesforce.com \
  --client-id 3MVG9... \
  --client-secret YOUR_SECRET \
  --sf-endpoint /services/apexrest/mcp/records
```

### Per-User Auth (individual identity — new)

When `--client-secret` is omitted, the system uses per-user auth:

```bash
npx salesforce-mcp-lib \
  --instance-url https://myorg.my.salesforce.com \
  --client-id 3MVG9... \
  --sf-endpoint /services/apexrest/mcp/records
```

The mode is auto-detected. No explicit flag needed.

---

## 6. Headless Environments (SSH, Docker, CI)

```bash
npx salesforce-mcp-lib login \
  --instance-url https://myorg.my.salesforce.com \
  --client-id 3MVG9... \
  --headless
```

The command prints an authorization URL. Open it in any browser (even on a different machine), authorize, then paste the callback URL back into the terminal.

---

## 7. Session Management

- **Automatic refresh**: Tokens are refreshed transparently when they expire
- **Session persistence**: Tokens survive across process restarts
- **Session expiry**: If a refresh token is revoked (admin action, password change), you'll be prompted to log in again
- **Switching users**: Delete `~/.salesforce-mcp-lib/tokens/` and run `login` again

---

## 8. Troubleshooting

| Problem | Solution |
|---------|----------|
| "No stored credentials found" | Run `npx salesforce-mcp-lib login` first |
| "Connected App client ID is not recognized" | Verify `--client-id` matches the Consumer Key in your External Client App / Connected App |
| "User does not have access to this Connected App" | In Salesforce Setup → External Client App → Policies → set "All users may self-authorize" or add your user's Profile/Permission Set |
| "Authorization was denied" | Click "Allow" when prompted during login, or retry |
| "Cannot reach instance" | Check network, VPN, and that the instance URL is correct |
| "Session expired and refresh failed" | Password changed or admin revoked access. Run `login` again |
| Port 13338 in use | Use `--callback-port 13339` (and add `http://localhost:13339/oauth/callback` to the External Client App) |
| Claude Code `/mcp` shows server disconnected | Re-run `login`, then restart the server from `/mcp` menu |
| "PKCE error" or "code_verifier required" | Ensure the External Client App has "Enable PKCE" checked |
| "redirect_uri_mismatch" | Ensure the callback URL in the External Client App matches exactly: `http://localhost:13338/oauth/callback` |
