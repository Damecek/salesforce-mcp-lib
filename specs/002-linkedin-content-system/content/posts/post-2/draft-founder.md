# Post 2 — Founder: The Hidden Cost of "Just Build an API" for AI Integration
**Topic**: 2 — The Hidden Cost of "Just Build an API" for AI Integration
**Variant**: Founder
**Word count**: 254
**Claims referenced**: C-002, C-007, C-014
---

I spent years building custom REST endpoints to connect AI tools to Salesforce. Every single one became a liability.

The first endpoint was fine. Clean code, good docs, proper auth. By the tenth, we had three different authentication patterns, credentials in two vaults and one config file that nobody remembered creating, and a Confluence page mapping endpoints to capabilities that was outdated before the ink dried.

The moment that stuck with me was watching an AI agent fail silently because someone renamed a field in the org and nobody updated the integration. The endpoint returned a 200 with empty results. No error. No signal. Just wrong answers flowing downstream.

That experience shaped a design decision in Salesforce MCP Library: the initialize handler advertises only the capabilities that are actually registered. If a tool exists, the agent knows about it -- its name, its input schema, its parameter types. If it doesn't exist, it's invisible. There's no stale mapping to maintain because the mapping is the code.

All 11 MCP protocol methods are implemented and wire-format verified. But what actually matters isn't protocol completeness -- it's that the agent can discover available tools, validate its own inputs against schemas, and execute within the org's existing security model. OAuth scopes, Profiles, Permission Sets, Sharing Rules -- four layers of authorization that your org already enforces.

If you're maintaining a spreadsheet of AI integration endpoints and their credentials, you already know the problem.

The question is whether you keep patching it or replace it with a protocol.
