# Post 7 - Business: The Problem Wasn't the Agent. It Was the Vocabulary

**Topic**: 7 - The Problem Wasn't the Agent. It Was the Vocabulary
**Variant**: Business
**Word count**: 211
**Claims referenced**: [C-001, C-011, C-013, C-014]

---

The tagged LinkedIn post captured a pattern many teams are about to run into.

An AI agent needed to update one Salesforce record. It got there eventually, but only after broad search attempts and a large fallback query. The outcome was technically correct. The path to get there was expensive.

That is usually not a model problem. It is a tooling problem.

Generic Salesforce connectors expose generic actions. Real teams need business operations. "Query accounts" is a primitive. "Update the renewal owner for the matched customer account" is an operation the business actually understands and an agent can choose with far less guesswork.

That is why I like the shape of `salesforce-mcp-lib`. The repo keeps the contract explicit: Apex code calls `registerTool()`, `registerResource()`, and `registerPrompt()` on `McpServer`, and the endpoint exposes only what you intentionally publish. The e2e example shows that mix in one endpoint class. You are not teaching the agent your whole org. You are giving it the right entry points.

The business benefit is straightforward: fewer wasteful queries, fewer brittle agent plans, and a lower chance that "autonomy" turns into hidden integration cost.

The lesson from the PoC is simple. If you want reliable agent behavior in Salesforce, design tools around business decisions, not around generic database reach.
