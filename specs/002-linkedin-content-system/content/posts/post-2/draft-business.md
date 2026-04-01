# Post 2 — Business: The Hidden Cost of "Just Build an API" for AI Integration
**Topic**: 2 — The Hidden Cost of "Just Build an API" for AI Integration
**Variant**: Business
**Word count**: 249
**Claims referenced**: C-007, C-009, C-014
---

Every custom REST endpoint you build for AI integration is a maintenance line item your team will carry forever.

I've watched this pattern repeat across orgs. A team needs an AI agent to read Salesforce data, so they build an endpoint. Then another team needs write access, so they build another with different authentication. Within a quarter, there are a dozen endpoints, credentials scattered across vaults and config files, and no single person who can tell you what the AI agent is actually authorized to do.

The hidden cost isn't building v1. It's maintaining v47 when three teams are adding tools and nobody owns the integration layer.

The real problem is structural. Custom endpoints don't support capability discovery. An AI agent can't ask "what can I do here?" -- someone has to manually map every available action, every parameter, every permission. That mapping rots the moment someone changes a field name.

MCP eliminates this entire category of work. With Salesforce MCP Library, the server dynamically advertises only registered capabilities. Agents discover what's available at runtime. When a Salesforce session expires, the proxy transparently re-authenticates -- the agent never sees the failure. And every request runs through Salesforce's existing four-layer authorization: OAuth scopes, Profiles, Permission Sets, and Sharing Rules.

No new credential stores. No middleware to maintain. No data leaving the org.

Before building your next AI integration endpoint, count the ones you already have. Then count the credential stores backing them.

The result will make the case for you.
