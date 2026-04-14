# Post 11 — Technical: Salesforce Hosted MCP Goes GA — An Honest Architectural Comparison

**Topic**: 11 — Salesforce Hosted MCP Goes GA — Where It Wins and Where salesforce-mcp-lib Remains Essential
**Variant**: Technical
**Word count**: 237
**Claims referenced**: [C-029, C-030, C-031, C-032, C-033]

---

Salesforce hosted MCP servers are GA. Here's an honest architectural comparison with salesforce-mcp-lib — where each solution fits and why both exist.

Hosted MCP ships four pre-built SObject servers that expose CRUD operations to AI agents with zero Apex. Fast to set up. But that's raw database access without business-logic guardrails — the agent sees every queryable field on every accessible object. salesforce-mcp-lib takes the opposite approach: every tool requires an explicit `McpToolDefinition` subclass with `inputSchema()`, `validate()`, and `execute()`. No shortcut, by design.

The transport architectures diverge. Hosted uses SSE with a dedicated `mcp_api` OAuth scope — narrower blast radius, the token can only reach MCP endpoints. salesforce-mcp-lib uses stdio (for desktop clients like Claude Code) or direct HTTPS (for cloud integrations), both with the standard `api` scope.

Authentication is where it gets interesting. Hosted MCP supports user-based identity only. salesforce-mcp-lib supports both: Authorization Code with PKCE for per-user access, and client_credentials for service accounts. CI/CD pipelines and scheduled batch jobs need that service identity — there's no browser to log into.

Tool registration: hosted configures tool sets declaratively via Setup UI. salesforce-mcp-lib builds them programmatically — `McpJsonRpcModuleBuilder` constructs a fresh module per request, meaning tool availability can vary by runtime state.

Both enforce Salesforce's full security model — CRUD, FLS, sharing rules. The platform security boundary is identical.

Explore both. The right choice depends on your deployment topology.
