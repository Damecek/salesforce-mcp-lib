# Post 1 — Founder: Your Salesforce Org Already Speaks AI — It Just Needs a Protocol

**Topic**: 1 — Your Salesforce Org Already Speaks AI — It Just Needs a Protocol
**Variant**: Founder
**Word count**: 262
**Claims referenced**: [C-001, C-002, C-022]

---

I kept watching teams build the same thing: custom REST endpoints to let AI agents talk to Salesforce. Each one slightly different. Each one a maintenance burden. Each one invisible to every other agent.

That's when I started paying attention to the Model Context Protocol. MCP gives AI agents a standard way to discover and call external capabilities — like USB for AI integrations. The problem was that no one had built a production-ready MCP server that runs natively in Apex, on the Salesforce platform itself.

So I built one.

Salesforce MCP Library implements the full MCP 2025-11-25 specification — all 11 protocol methods, wire-format verified. It's a two-layer design: stateless Apex inside the org handles the business logic, and a lightweight TypeScript proxy handles OAuth and transport. The entire stack has zero external production dependencies. No third-party Apex libraries. No npm packages. Just platform APIs and Node.js built-ins.

I made that choice deliberately. When your protocol layer has zero dependencies, there's nothing to audit, nothing that breaks when someone else pushes a bad release, and nothing between your security team and a clean review.

The part I'm most proud of is the developer surface. A working endpoint is 12 lines of Apex — see `MinimalMcpEndpoint.cls` in the examples folder. I wanted someone to go from cloning the repo to having AI agents talking to their Salesforce org in an afternoon. Not a sprint. An afternoon.

The repo is open source. Star it, try the minimal example, and tell me what you'd build with it.
