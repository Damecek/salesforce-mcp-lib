# Post 10 — Technical: Per-User OAuth for MCP — Every Request Runs as the Actual User

**Topic**: 10 — Per-User OAuth: When the AI Agent Should Run as You, Not as a Service Account
**Variant**: Technical
**Word count**: 267
**Claims referenced**: [C-023, C-024, C-026, C-027]

---

Most MCP-to-Salesforce setups use a single service account for every request. One set of credentials, one profile, one set of sharing rules — regardless of who is actually asking the question.

That means the AI agent either sees too much (admin-level access for everyone) or too little (restricted to the lowest common denominator). Neither is correct.

In the latest release of `salesforce-mcp-lib`, we added OAuth 2.0 Authorization Code with PKCE as a second auth mode. The detection is automatic: if `--client-secret` is present, the proxy uses client_credentials as before. Remove it, and it switches to per-user auth.

Here's what happens under the hood:

1. `salesforce-mcp-lib login` starts a local callback server, generates a PKCE challenge (32 random bytes, SHA-256 S256), and opens the browser.
2. User authenticates with their own Salesforce credentials.
3. Tokens are exchanged, encrypted with AES-256-GCM, and stored in `~/.salesforce-mcp-lib/tokens/` (mode 0600).
4. On next proxy start, stored tokens are loaded and refreshed transparently.

The callback server validates the OAuth state parameter for CSRF prevention — and on a mismatch, it keeps listening for the legitimate callback instead of failing immediately. This prevents LAN-based spoofing from hijacking the login session.

The `AuthStrategy` interface is the same for both flows: `getAccessToken()`, `reauthenticate()`, `getInstanceUrl()`. The proxy runtime doesn't care which flow produced the token.

The result: each user's MCP requests run under their own profile, permission sets, and sharing rules. The AI agent sees exactly what that user would see in the Salesforce UI.

Zero new dependencies. Fully backward compatible.
