# Post 1 — Technical: Your Salesforce Org Already Speaks AI — It Just Needs a Protocol

**Topic**: 1 — Your Salesforce Org Already Speaks AI — It Just Needs a Protocol
**Variant**: Technical
**Word count**: 248
**Claims referenced**: [C-001, C-002, C-012, C-022]

---

Every AI-to-Salesforce integration I've seen follows the same pattern: pull data out, transform it, push it into a model. It works until it doesn't — and it stops working the moment you need real-time data, row-level security, or more than a handful of tools.

The Model Context Protocol (MCP) offers a different path. Instead of moving data to the AI, the AI discovers and calls capabilities where the data already lives.

Salesforce MCP Library is a native Apex implementation of MCP 2025-11-25. All 11 protocol methods — from `initialize` through `tools/call`, `resources/read`, and `prompts/get` — are implemented and wire-format verified against the spec. The architecture is two layers: a stateless Apex server that rebuilds per request inside governor limits, paired with a TypeScript stdio proxy that handles OAuth and transport. Both layers carry zero external production dependencies — 77 Apex classes and 6 TypeScript modules, all using only platform-native APIs and Node.js built-ins.

The developer surface is deliberately small. A working MCP endpoint with one registered tool is 12 lines of Apex — a `@RestResource` class that instantiates `McpServer`, registers a tool, and calls `handleRequest()`. You can see it in `MinimalMcpEndpoint.cls`.

What makes this interesting architecturally: AI agents connect through a standard protocol, discover available tools dynamically, validate inputs against schemas, and execute within the org's existing security perimeter. No middleware. No data replication. No custom REST endpoints to maintain.

Star the repo and deploy the minimal example — it takes less time than reading this post.
