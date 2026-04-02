# Post 6 — Technical: Salesforce Has a New Interface — This One Is for AI Agents

**Topic**: 6 — Salesforce Has a New Interface — This One Is for AI Agents
**Variant**: Technical
**Word count**: 228
**Claims referenced**: C-001, C-010, C-008, C-013

---

`McpToolDefinition` has three methods: `inputSchema()`, `validate()`, `execute()`. That's the interface between an AI agent and your Salesforce business logic.

Your org has SOQL queries behind record pages. It has subflows invoked by screen flows. It has validation rules, approval processes, and automation on every object. All of it was built for humans clicking through a UI.

`ExampleQueryTool` in the repo shows the pattern: extend `McpToolDefinition`, put your existing SOQL inside `execute()`, define input parameters in `inputSchema()`. The same Account query a sales rep sees on a record page now responds to `tools/call` from any MCP-compatible agent. The framework handles protocol compliance — `tools/list` advertises the tool, JSON Schema validates inputs, the two-tier error model separates protocol failures from tool failures.

What makes this work architecturally: the Apex endpoint is stateless, rebuilt per request. A TypeScript proxy handles session state and OAuth. Your existing profiles, permission sets, and sharing rules enforce the same access boundaries for the agent as for the human. No new security layer to build.

The real shift is conceptual. Salesforce always had the data and the logic. It had an interface for humans — record pages, screen flows, reports. `salesforce-mcp-lib` adds the interface for AI agents. Same logic, same security, different consumer.

Explore `ExampleQueryTool.cls` in the repo — you'll see how one SOQL query becomes an agent-callable tool in under 35 lines of Apex.
