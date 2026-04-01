# Hooks: Post 5 — From Zero to AI-Enabled Org in 30 Lines of Apex
**Topic**: 5 — From Zero to AI-Enabled Org in 30 Lines of Apex

## 1. Pain-First
Your team spent three weeks evaluating an AI integration platform -- procurement, sandbox provisioning, middleware configuration -- and still doesn't have a working prototype.
Meanwhile, a single `sf project deploy start` command and 12 lines of Apex would have had AI agents talking to your Salesforce org before lunch.

## 2. Misconception-First
People assume connecting AI to Salesforce requires middleware, a vendor contract, and a multi-sprint implementation plan.
It requires two Apex classes and a single deploy command. The entire endpoint is 12 lines of code, the npm proxy has zero production dependencies, and your org's existing security model applies from the first request.

## 3. Architecture-First
Two classes. 30 lines of Apex. One `@RestResource` endpoint instantiates `McpServer` and registers capabilities; one tool definition extends `McpToolDefinition` with three methods -- `inputSchema()`, `validate()`, `execute()`.
Deploy, connect with `npx salesforce-mcp-lib`, and an AI agent discovers your tools through the standard MCP protocol handshake. No middleware layer in between.

## 4. Business-First
The biggest risk in AI integration isn't choosing the wrong framework -- it's spending so long evaluating frameworks that you never ship anything.
Salesforce MCP Library deploys with a single CLI command, requires zero procurement, and inherits your existing security model. Your team can have a working prototype before the next standup.

## 5. Curiosity-First
What if you could go from an empty scratch org to a fully MCP-compliant AI integration in less time than it takes to read your org's security review checklist?
Two Apex classes, one deploy command, and `npx salesforce-mcp-lib`. The E2E example registers tools, resources, and prompts in 14 lines.
