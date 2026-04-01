# Post 5 — Founder: From Zero to AI-Enabled Org in 30 Lines of Apex
**Topic**: 5 — From Zero to AI-Enabled Org in 30 Lines of Apex
**Variant**: Founder
**Word count**: 269
**Claims referenced**: [C-012, C-013, C-021, C-010, C-019]
---

I set one rule for myself when building Salesforce MCP Library: someone should be able to go from cloning the repo to talking to their org through an AI agent in an afternoon. Not a sprint. Not a week of configuration. An afternoon.

That constraint shaped every design decision. The package ships as a 2GP with no namespace -- you write `McpServer`, not `ns.McpServer`. The developer surface is four abstract classes with 1 to 3 methods each. A complete endpoint is 12 lines of Apex: a `@RestResource` class that instantiates the server, registers a tool, and calls `handleRequest()`. Deploy it with one CLI command. Connect with `npx salesforce-mcp-lib`. Done.

I built two example tiers for a reason. The minimal example is the "does this thing actually work?" proof -- an echo tool that validates the full round-trip from AI agent through the proxy into Apex and back. The E2E example is the "what can I actually build with this?" answer -- SOQL queries, org metadata as resources, dynamic prompts, all registered in a single 14-line endpoint class.

The part that still surprises people: none of this requires new security infrastructure. The moment you deploy, the endpoint inherits your org's OAuth scopes, Profiles, Permission Sets, and Sharing Rules. The AI agent gets exactly the access your integration user has -- nothing more.

I've watched teams go from "what is MCP?" to "this is running in our sandbox" in a single session. That's the experience I optimized for.

Clone the repo, deploy the minimal example, and see for yourself. I'd love to hear what you build first.
