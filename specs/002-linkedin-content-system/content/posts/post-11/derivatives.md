# Derivatives: Post 11 — Salesforce Hosted MCP Goes GA

**Source variant**: business
**Generated**: 2026-04-14

## Short Post

**Word count**: 89 (max: 100)

Salesforce hosted MCP servers are GA. Pre-built SObject CRUD, Tableau Next, dedicated `mcp_api` scope — great for standard use cases.

Three gaps remain: no service account auth (client_credentials), no stdio/HTTP transports for desktop or custom integrations, and no explicit tool boundaries — hosted exposes raw CRUD while salesforce-mcp-lib requires every tool to define `McpToolDefinition` with inputSchema, validate, and execute.

Both enforce the same Salesforce security model. Use hosted for standard access. Use salesforce-mcp-lib when you need more control.

## Carousel Script

**Slides**: 7 (target: 5–8)

### Slide 1: Salesforce Hosted MCP Is Now GA
Salesforce just launched hosted MCP servers for Enterprise Edition and above. Pre-built SObject servers, Tableau Next, Flows-as-tools — 30 minutes to connect an AI agent. Big news for the ecosystem.

### Slide 2: Where Hosted MCP Wins
Instant CRUD access, dedicated `mcp_api` OAuth scope (narrower blast radius), and SSE transport with built-in token handling. If you need standard Salesforce data access for AI agents, this is the fastest path.

### Slide 3: Gap #1 — No Service Accounts
Hosted MCP requires user-based identity for every request. CI/CD pipelines, batch jobs, and backend integrations don't have a browser. salesforce-mcp-lib supports both per-user PKCE and client_credentials for service accounts.

### Slide 4: Gap #2 — Raw CRUD vs Explicit Tools
Hosted ships pre-built SObject servers that expose raw CRUD. salesforce-mcp-lib requires every tool to define `McpToolDefinition` with inputSchema(), validate(), and execute(). The agent only sees what you deliberately expose.

### Slide 5: Gap #3 — Transport Topology
Hosted uses SSE — cloud-native, always-connected. salesforce-mcp-lib offers stdio (for Claude Code, desktop agents) and direct HTTP (for cloud platforms with their own OAuth). Different transports for different deployment realities.

### Slide 6: Same Security Underneath
Both enforce CRUD, FLS, sharing rules, profiles, and permission sets. The Salesforce platform security model is identical regardless of which MCP approach you use.

### Slide 7: Use Both — They're Complementary
Hosted for standard access. salesforce-mcp-lib for service accounts, explicit tool boundaries, and non-SSE transports. Salesforce investing in hosted MCP validates the protocol for the entire ecosystem. Star the repo to follow what's next.

## Comment Version

**Sentences**: 3 (target: 2–3)

Congrats to the Salesforce team on hosted MCP going GA — this validates MCP as the standard for AI-to-Salesforce integration. We built salesforce-mcp-lib for the use cases hosted doesn't cover yet: service account auth, explicit tool boundaries via McpToolDefinition, and stdio/HTTP transports for desktop and custom deployments. Both enforce the same platform security model — complementary, not competing.

## DM Explanation

**Sentences**: 4 (target: 3–5)

So Salesforce launched hosted MCP servers — basically pre-built SObject access, Tableau, Flows-as-tools, all configurable from Setup. It's great for standard stuff but doesn't support service accounts (client_credentials), only user-based auth, and the pre-built CRUD gives agents raw database access without business logic guardrails. salesforce-mcp-lib is still the play when you need explicit tool definitions (every tool has inputSchema + validate + execute), service account auth for CI/CD, or stdio transport for desktop agents. They actually work well together — hosted for reads, salesforce-mcp-lib for controlled writes.

---

## Validation

- Short post word count: 89 (max: 100)
- Carousel slides: 7 (target: 5–8)
- Comment sentences: 3 (target: 2–3)
- DM sentences: 4 (target: 3–5)
- Core message preserved: YES
- Key repo fact preserved: YES
