# Post 4 — Business: Four Layers of Security You Didn't Have to Build

**Topic**: 4 — Four Layers of Security You Didn't Have to Build
**Variant**: Business
**Word count**: 262
**Claims referenced**: [C-014, C-015, C-017, C-018]

---

The first question every security review asks about AI integrations: "How do you control what the agent can access?"

If your team built a custom integration, the answer usually involves a long explanation of bespoke middleware, hand-rolled permission checks, and a new credential management layer. That's weeks of engineering and a permanent maintenance burden.

With Salesforce MCP Library, the answer is shorter: "The same way we control what our users can access."

The library inherits four authorization layers your org already enforces. Connected App OAuth scopes limit API access. Profiles and Permission Sets control which objects and fields are visible. OWD and Sharing Rules determine which records the agent can reach. And developers can add tool-specific validation logic for anything the platform doesn't cover natively. No new permission system to build, audit, or keep synchronized.

The operational details reinforce this. The OAuth 2.0 client credentials flow handles authentication with automatic token caching — no interactive login flows to manage. Secrets are redacted in all log output, with `client_secret` replaced by `"****"` at the logging layer. And raw Salesforce errors are sanitized before they reach the AI client, so internal system details never leak across the boundary.

For engineering managers planning AI adoption: this means your existing Salesforce security investment carries forward. Every Profile, every Permission Set, every Sharing Rule your team has already configured applies automatically to AI agent access.

Take your current permission model and identify which Salesforce tools you could safely expose to AI agents today — without building anything new.
