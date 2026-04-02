# Post 6 — Founder: Salesforce Has a New Interface — This One Is for AI Agents

**Topic**: 6 — Salesforce Has a New Interface — This One Is for AI Agents
**Variant**: Founder
**Word count**: 218
**Claims referenced**: C-001, C-012, C-022

---

I kept staring at the same problem from both sides.

On one side: a Salesforce org with everything — accounts, opportunities, cases, custom objects, screen flows, validation rules, approval processes. Years of business logic, encoded and tested.

On the other side: AI agents that couldn't reach any of it. Or could, but only through custom REST endpoints someone had to build, secure, maintain, and document. Every integration was bespoke. Every tool hand-wired.

The thing that struck me: Salesforce already has interfaces. Record pages for viewing data. Screen flows for guided data entry. Reports for analysis. But all of them assume a human on the other end.

So I built `salesforce-mcp-lib` — an open-source MCP server framework in native Apex. It adds one more interface to Salesforce. This one is for AI agents.

The pattern is deliberately simple. Take `ExampleQueryTool.cls`: extend `McpToolDefinition`, put a SOQL query in `execute()`, define the input schema. That's a tool any MCP-compatible agent can discover and call. The same query a rep sees on a record page — now available to Claude, GPT, or any agent speaking MCP.

Zero external dependencies. 77 Apex classes. Ships as a 2GP unlocked package. The business logic stays in your org. The agents just get a new way in.

What screen flows in your org could become AI agent tools tomorrow?
