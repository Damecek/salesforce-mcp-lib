# Post 10 — Founder: Per-User OAuth for MCP — Every Request Runs as the Actual User

**Topic**: 10 — Per-User OAuth: When the AI Agent Should Run as You, Not as a Service Account
**Variant**: Founder
**Word count**: 258
**Claims referenced**: [C-023, C-024, C-026, C-028]

---

When I shipped the first version of `salesforce-mcp-lib`, it used client_credentials — one service account, one token, all requests running under the same identity.

It worked. And it immediately created a question I kept hearing: "Can each user log in with their own account?"

The answer was always "eventually." This month it became "yes."

The proxy now supports OAuth 2.0 Authorization Code with PKCE. Users run `salesforce-mcp-lib login`, authenticate through their browser, and the tokens are encrypted and stored locally. Next time the MCP server starts, it picks up the stored credentials automatically.

The implementation decision I'm most satisfied with: backward compatibility via auto-detection. If `--client-secret` is in the config, the proxy uses client_credentials exactly as before. Remove it, and it switches to per-user auth. No migration, no breaking change, no new flags to learn.

Building the token store was where things got interesting. Tokens are encrypted with AES-256-GCM and written atomically (via rename). The encryption key lives in a separate file with owner-only permissions. It's not OS keychain integration — the honest threat model is in the code comments — but it protects against the common case of backup and disk-image leakage.

The callback server took more hardening than I expected. CSRF state validation, LAN-based spoofing prevention, graceful port fallback, headless mode for environments without a browser.

But the outcome is worth it: the AI agent now inherits Salesforce's per-user security model. Exactly as it should have from the start.
