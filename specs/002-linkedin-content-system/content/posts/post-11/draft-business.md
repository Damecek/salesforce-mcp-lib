# Post 11 — Business: Salesforce Hosted MCP Goes GA — Where It Wins and Where salesforce-mcp-lib Remains Essential

**Topic**: 11 — Salesforce Hosted MCP Goes GA — Where It Wins and Where salesforce-mcp-lib Remains Essential
**Variant**: Business
**Word count**: 248
**Claims referenced**: [C-029, C-030, C-031, C-032, C-033, C-014]

---

Salesforce just made hosted MCP servers generally available. If you've been following salesforce-mcp-lib, the natural question is: do you still need it?

Honest answer: it depends on what you're building.

Hosted MCP is the right choice for teams that want Salesforce data exposed to AI agents with minimal setup. Four pre-built SObject servers, Tableau Next integration, Flows-as-tools, and a dedicated `mcp_api` OAuth scope that limits token access to MCP endpoints only. Thirty minutes from Setup to connected agent. Hard to beat for standard use cases.

But three gaps remain.

First: service account authentication. Hosted MCP requires a user identity for every request. Your nightly data sync, your CI/CD pipeline, your backend integration — they don't have a browser to log in with. salesforce-mcp-lib supports both per-user OAuth with PKCE and client_credentials for service accounts.

Second: tool surface control. Hosted MCP's pre-built SObject servers give AI agents raw CRUD access. salesforce-mcp-lib requires every tool to define an explicit input schema and validation logic via `McpToolDefinition`. The agent only sees what you deliberately expose.

Third: deployment topology. Hosted runs SSE, cloud-native. salesforce-mcp-lib runs stdio for desktop agents or direct HTTP for custom integrations. Different transports for different environments.

Both enforce the same Salesforce security model — profiles, permission sets, sharing rules. The platform security is identical.

The real story: Salesforce investing in hosted MCP validates the protocol for the entire ecosystem. Use hosted for standard access. Use salesforce-mcp-lib when you need service accounts, explicit tool boundaries, or non-SSE transports.
