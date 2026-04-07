# Research: Per-User Salesforce Authentication

**Feature**: 003-per-user-auth | **Date**: 2026-04-07

## R1: Salesforce OAuth 2.0 Authorization Code Flow with PKCE

**Decision**: Use Authorization Code flow with PKCE for per-user login.

**Rationale**: This is Salesforce's recommended flow for user-facing applications that need individual user identity. The flow works as follows:

1. Generate PKCE code_verifier (random 128-byte string, base64url-encoded) and code_challenge (SHA-256 hash of code_verifier, base64url-encoded)
2. Redirect user to `{instanceUrl}/services/oauth2/authorize` with params:
   - `response_type=code`
   - `client_id={clientId}`
   - `redirect_uri=http://localhost:{port}/oauth/callback`
   - `code_challenge={code_challenge}`
   - `code_challenge_method=S256`
3. User authenticates in browser, grants consent
4. Salesforce redirects to callback URL with `?code={authorization_code}`
5. Exchange code at `{instanceUrl}/services/oauth2/token` with:
   - `grant_type=authorization_code`
   - `code={authorization_code}`
   - `client_id={clientId}`
   - `redirect_uri={redirect_uri}` (must match exactly)
   - `code_verifier={code_verifier}` (PKCE proof)
6. Response includes `access_token`, `refresh_token`, `instance_url`, `id`, `issued_at`, `token_type`

**Key findings**:
- PKCE eliminates the need for `client_secret` in the token exchange, making it safe for local/public clients
- The `/services/oauth2/authorize` endpoint works on any Salesforce instance URL (My Domain, sandbox, production)
- Salesforce access tokens typically expire based on org session settings (default ~2 hours)
- Refresh tokens are long-lived (can be revoked by admin, expire after policy-defined period)
- The `id` field in the token response is a URL that returns user identity info when fetched

**Alternatives considered**:
- JWT Bearer flow: Requires X.509 certificate upload to Connected App, complex admin setup
- Device Authorization Grant (RFC 8628): Not supported by Salesforce
- Username-Password flow: Deprecated, does not support MFA, blocked on many orgs
- SAML assertion flow: Not applicable for CLI/API tools

## R2: Token Refresh Mechanism

**Decision**: Use OAuth 2.0 refresh_token grant for transparent session renewal.

**Rationale**: Salesforce issues a refresh_token with the Authorization Code flow. The refresh flow:

1. POST to `{instanceUrl}/services/oauth2/token` with:
   - `grant_type=refresh_token`
   - `refresh_token={stored_refresh_token}`
   - `client_id={clientId}`
2. Response includes new `access_token` (and potentially new `refresh_token`)

**Key findings**:
- Refresh tokens survive across process restarts (they're not session-bound)
- Refresh tokens can be revoked by Salesforce admin (user deactivation, Connected App policy change)
- A failed refresh (HTTP 400 with `invalid_grant`) means the user must re-authenticate interactively
- The refresh response may or may not include a new refresh_token — if present, store the new one
- No client_secret is needed for refresh when the original flow used PKCE

**Alternatives considered**:
- Re-authenticate from scratch on every startup: Poor UX, violates FR-003
- Use access_token expiry header to predict refresh timing: Salesforce doesn't reliably expose TTL

## R3: Token Storage Security

**Decision**: File-based storage with OS file permissions (mode 0600).

**Rationale**: Research into how similar tools handle credential storage:

| Tool | Storage Method | Dependencies |
|------|---------------|--------------|
| Salesforce CLI (`sf`) | `~/.sf/` JSON files | None (built-in) |
| Git | `~/.git-credentials` plain text | None (built-in) |
| SSH | `~/.ssh/` key files with 0600 | None (built-in) |
| AWS CLI | `~/.aws/credentials` plain text | None (built-in) |
| GitHub CLI (`gh`) | `~/.config/gh/hosts.yml` | None (built-in) |

**Key findings**:
- Industry standard for CLI tools is file-based storage with file permissions
- OS file permissions (0600 = owner-only read/write) provide effective protection against other users on the same machine
- Encryption at rest adds complexity without meaningful security gain when the decryption key must also be on the same machine
- Node.js `node:fs.writeFile` with `mode: 0o600` works on macOS/Linux; Windows uses ACLs automatically
- Storage directory: `~/.salesforce-mcp-lib/tokens/` follows XDG-like conventions
- File naming: `{sha256(instanceUrl + clientId)}.json` to support multiple orgs without exposing org details in filenames

**Alternatives considered**:
- OS Keychain (macOS Keychain, Windows Credential Manager): Requires native bindings or shelling out to platform-specific CLIs — violates zero-dependency constraint
- Encrypted file with PBKDF2-derived key: Key would be derived from machine-local data, adding complexity without real security benefit
- SQLite: Would require a native npm dependency

## R4: Browser Launch Mechanism

**Decision**: Use `node:child_process.exec` with platform-specific commands.

**Rationale**: Opening a browser from Node.js without npm dependencies requires platform detection:

| Platform | Command |
|----------|---------|
| macOS | `open {url}` |
| Linux | `xdg-open {url}` |
| Windows | `start "" "{url}"` |
| WSL | `wslview {url}` or `cmd.exe /c start "" "{url}"` |

**Key findings**:
- `process.platform` reliably returns `darwin`, `linux`, or `win32`
- Browser open should be fire-and-forget (don't wait for browser to close)
- If the command fails (headless server, SSH), fall back to printing the URL to stderr
- The `open` command on macOS returns immediately; `xdg-open` on Linux may block briefly
- Use `{ timeout: 5000 }` to prevent hanging if the command blocks unexpectedly

**Alternatives considered**:
- `open` npm package: Adds a production dependency — violates zero-dependency constraint
- Hardcoded browser path: Not portable

## R5: Local Callback Server Design

**Decision**: Ephemeral `node:http` server on port 13338 (configurable).

**Rationale**: The OAuth redirect requires a local HTTP endpoint to receive the authorization code.

**Key findings**:
- The callback URL (`http://localhost:{port}/oauth/callback`) must be registered in the Connected App settings
- Fixed default port (13338) simplifies Connected App configuration
- If port is occupied, try incrementing (13339, 13340, ...) up to 5 attempts
- Server should only accept GET requests to `/oauth/callback`
- Server should shut down immediately after receiving the code
- Respond with an HTML page saying "Login successful! You can close this tab."
- Include CSRF protection: verify the `state` parameter matches what was sent
- Timeout: If no callback received within 120 seconds, shut down and report error

**Alternatives considered**:
- Random port: Admin can't pre-configure Connected App callback URLs
- Named pipe: Not portable, overly complex
- Long-polling: Adds unnecessary complexity and latency

## R6: Headless Login Flow

**Decision**: Separate `login` subcommand with `--headless` flag that reads authorization code from stdin.

**Rationale**: The main MCP process cannot use stdin interactively (reserved for JSON-RPC). For environments without a browser:

**Flow**:
1. User runs: `salesforce-mcp-lib login --instance-url ... --client-id ... --headless`
2. System prints to stderr: authorization URL
3. System also starts local HTTP server (in case redirect works)
4. User opens URL on any device with a browser
5. After authorization, either:
   a. Redirect reaches localhost → code captured automatically
   b. Redirect fails → user copies the full callback URL from browser and pastes it into the terminal
6. System extracts authorization code, exchanges for tokens, stores them

**Key findings**:
- Salesforce will redirect the browser to `http://localhost:13338/oauth/callback?code=...`
- If the browser is on a different machine, the redirect fails — user sees the URL in browser address bar
- User can copy the full URL and paste it (the code is in the query string)
- Parsing the code from a pasted URL is straightforward: `new URL(pasted).searchParams.get('code')`
- The login subcommand can use stdin freely since it's not running as an MCP server

**Alternatives considered**:
- QR code in terminal: Cool but unreliable across terminal emulators
- Polling Salesforce for auth status: No API for this in standard OAuth
- Environment variable with pre-obtained token: Violates FR-002 (guided flow)

## R7: Error Classification for Auth Failures

**Decision**: Map Salesforce OAuth error codes to specific error subclasses.

**Rationale**: FR-008 requires distinct, actionable error messages. Salesforce OAuth errors follow a pattern:

| Salesforce Error | HTTP Status | Our Error Class | User Message |
|-----------------|-------------|-----------------|--------------|
| `invalid_grant` | 400 | `InvalidCredentialsError` | "Your Salesforce credentials were rejected. Check your username and password, or try logging in again." |
| `invalid_client_id` | 400 | `InvalidCredentialsError` | "The Connected App client ID is not recognized. Verify the client_id in your configuration." |
| `invalid_client` | 401 | `InvalidCredentialsError` | "Connected App authentication failed. Verify client_id and Connected App settings." |
| `unauthorized_client` | 400 | `InsufficientAccessError` | "Your Salesforce user does not have access to this Connected App. Contact your administrator." |
| `access_denied` | 400 | `ConsentDeniedError` | "Authorization was denied. The application requires your consent to access Salesforce." |
| `INVALID_SESSION_ID` | 401 | `SessionExpiredError` | "Your session has expired. Attempting to refresh..." |
| Network error | N/A | `ConnectivityError` | "Cannot reach {instanceUrl}. Check your network connection and instance URL." |
| Timeout | N/A | `ConnectivityError` | "Connection to Salesforce timed out. The org may be undergoing maintenance." |

**Key findings**:
- Salesforce returns `error` and `error_description` fields in OAuth error responses
- The `error_description` is often technical — we should wrap it with user-friendly guidance
- HTTP 400 errors from the token endpoint are always auth-related
- HTTP 401/403 during regular API calls may be session expiry vs. permission issues
- Differentiating connectivity issues from auth issues requires catching network errors separately

**Alternatives considered**:
- Single generic auth error with message variations: Harder for agents and tools to handle programmatically
- Error codes as numbers: Less descriptive than named error classes

## R8: Backward Compatibility Strategy

**Decision**: Zero-change compatibility for existing client credentials configurations.

**Rationale**: The existing BridgeConfig with `clientSecret` as required must continue to work.

**Approach**:
1. `BridgeConfig.clientSecret` remains in the type but the actual runtime config type becomes `AuthConfig` where `clientSecret` is optional
2. `parseConfig()` no longer requires `clientSecret` — removes it from REQUIRED_KEYS
3. Auth mode detection: `config.clientSecret ? 'client_credentials' : 'authorization_code'`
4. The `authenticate()` function in oauth.ts is preserved as the client credentials implementation
5. Both flows produce the same `OAuthTokenResponse` shape — the bridge doesn't care which flow was used
6. CLI usage message updated to show `--client-secret` as optional

**Key findings**:
- Existing MCP client configs (e.g., Claude Desktop `claude_desktop_config.json`) provide all four fields including `--client-secret` → auto-detected as client credentials → behavior identical to v1.0.x
- New per-user configs omit `--client-secret` → auto-detected as per-user auth
- The bridge's `forward()` function works identically regardless of auth mode — it just reads the cached token
- Re-auth on 401: client credentials calls `authenticate()` again; per-user calls `refresh()` then falls back to re-login prompt

**Alternatives considered**:
- Explicit `--auth-mode` flag: Adds configuration complexity, contradicts spec clarification ("auto-detect from credentials")
- Separate binary/entry point for per-user mode: Fragments the user experience
