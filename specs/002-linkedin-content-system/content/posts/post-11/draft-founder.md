# Post 11 — Founder: Salesforce Hosted MCP Goes GA — Where It Wins and Where salesforce-mcp-lib Remains Essential

**Topic**: 11 — Salesforce Hosted MCP Goes GA — Where It Wins and Where salesforce-mcp-lib Remains Essential
**Variant**: Founder
**Word count**: 243
**Claims referenced**: [C-029, C-030, C-031, C-032, C-033, C-010]

---

When Salesforce announces a hosted version of the protocol your open-source project implements, you feel two things simultaneously: validated and nervous.

Today, Salesforce hosted MCP servers hit GA. Pre-built SObject access, Tableau Next, Data Cloud SQL, Flows-as-tools — all configurable from Setup with a dedicated `mcp_api` scope. I genuinely think this is great for the ecosystem.

And salesforce-mcp-lib isn't going anywhere. Here's why.

We built it for a specific design philosophy: every tool surface is explicit. When you extend `McpToolDefinition`, you define `inputSchema()`, `validate()`, and `execute()`. There's no "expose all SObjects" switch. That was deliberate — because giving an AI agent raw database access and giving it a curated set of business operations are fundamentally different things.

Hosted MCP fills a gap we never tried to fill: instant CRUD access for standard use cases. It also introduces a tighter security boundary with `mcp_api` — something we don't have yet. salesforce-mcp-lib uses the broader `api` scope.

Where we're still essential: service account authentication via client_credentials for CI/CD and batch jobs, stdio transport for desktop agents like Claude Code, direct HTTP for cloud integrations, and programmatic tool registration that adapts per request.

The honest comparison: hosted MCP configures tool sets. salesforce-mcp-lib computes them. Both enforce the same Salesforce security model underneath.

Use both. Hosted for standard patterns. salesforce-mcp-lib when you need explicit tool boundaries, service accounts, or non-SSE deployment topologies.

Star the repo if you want to see where this goes next.
