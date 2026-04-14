# Post 10 — Business: Per-User OAuth for MCP — Every Request Runs as the Actual User

**Topic**: 10 — Per-User OAuth: When the AI Agent Should Run as You, Not as a Service Account
**Variant**: Business
**Word count**: 248
**Claims referenced**: [C-023, C-024, C-025, C-026]

---

There's a pattern I keep seeing in enterprise AI integrations: one service account connecting the AI agent to Salesforce, shared across every user in the org.

It's fast to set up. It's also a security problem you'll be explaining to your auditor in six months.

When every request goes through a single identity, you lose the one thing Salesforce does exceptionally well — per-user access control. Profiles, permission sets, sharing rules, field-level security — all of it collapses into whatever the service account can see.

The latest release of `salesforce-mcp-lib` solves this with per-user OAuth. Each user authenticates once with their own Salesforce identity via the browser. Tokens are stored locally, encrypted with AES-256-GCM, and refreshed automatically.

The switch is simple: remove the `--client-secret` flag from your config. That's it. The proxy auto-detects the auth mode and uses Authorization Code with PKCE instead.

From that point on, every MCP request the AI agent makes runs under that specific user's permissions. If they can't see a field in the Salesforce UI, they can't see it through the AI agent either. No custom authorization layer needed.

When something goes wrong, the proxy tells users exactly what happened — five specific error classes map to clear guidance: "check your password," "contact your administrator," or "try logging in again."

Your existing client_credentials deployments keep working unchanged. Per-user auth is additive, not a migration.
