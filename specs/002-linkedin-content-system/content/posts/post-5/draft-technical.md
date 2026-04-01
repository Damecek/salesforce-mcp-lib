# Post 5 — Technical: From Zero to AI-Enabled Org in 30 Lines of Apex
**Topic**: 5 — From Zero to AI-Enabled Org in 30 Lines of Apex
**Variant**: Technical
**Word count**: 272
**Claims referenced**: [C-012, C-013, C-010, C-021, C-019]
---

Most enterprise AI "getting started" guides should really be called "getting started in two weeks after procurement approves the middleware license."

Here's what it actually takes to stand up a working MCP endpoint in Salesforce. Two classes, roughly 30 lines of Apex total.

The first class is a `@RestResource` endpoint -- 12 lines. It instantiates `McpServer`, registers a tool, and calls `handleRequest()`. That's the entire server. No configuration files, no XML wiring, no dependency injection. The package ships as a 2GP with no namespace, so you reference `McpServer` directly -- not `ns.McpServer`, not a managed prefix.

The second class is your tool definition. Extend `McpToolDefinition`, implement three methods -- `inputSchema()`, `validate()`, `execute()` -- and you have a capability that any MCP-compatible AI agent can discover and invoke. Need resources or prompts instead? The E2E example registers all three capability types -- a tool, a resource, and a prompt -- in a single 14-line endpoint class.

Deployment is a single CLI command:

`sf project deploy start --source-dir examples/minimal/force-app --target-org <org>`

No build step. No artifact assembly. Connect the proxy with `npx salesforce-mcp-lib`, point Claude Desktop or the MCP Inspector at it, and the agent discovers your registered capabilities through the standard protocol handshake.

The library ships two example tiers deliberately. The minimal example validates the concept -- deploy, connect, confirm the echo tool responds. The E2E example adds SOQL queries, org metadata resources, and dynamic prompts so you can see the full capability surface before writing your own.

Clone the repo and deploy the minimal example to a scratch org. It'll be running before your next meeting starts.
