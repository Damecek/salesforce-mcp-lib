# Post 8 - Technical: Dynamic Tool Registration or Separate Endpoints? Pick the Boundary Deliberately

**Topic**: 8 - Dynamic Tool Registration or Separate Endpoints? Pick the Boundary Deliberately
**Variant**: Technical
**Word count**: 223
**Claims referenced**: [C-007, C-011, C-014]

---

One design choice in Salesforce MCP is easy to underestimate: should different users see different tools through one endpoint, or should you publish separate endpoints with different capability sets?

The repo makes the first option viable because registration is programmatic and happens on every request. `McpServer` exposes explicit `registerTool()` calls, and the framework advertises only the categories that actually contain registered definitions. The public API contract even calls out stateless per-request registration as a deliberate design choice.

That means you can do something like:

`if (FeatureManagement.checkPermission('MCP_Can_Query_Accounts')) { server.registerTool(new QueryAccountsTool()); }`

I would use that pattern when the MCP surface is logically one product, but tool visibility should vary by user, permission set, or rollout stage. Same endpoint, same transport, different discovered tools at runtime.

The second option is harder isolation: multiple `@RestResource` endpoints, often paired with different External Client Apps and different run-as policies. The authorization report in the repo is clear about the trade-off: one endpoint shares one run-as permission model, while multiple permission levels may justify multiple endpoints.

So the choice is not technical style. It is boundary design.

Use dynamic registration for fine-grained variation inside one trust boundary.
Use separate endpoints when you need hard separation of auth policy, lifecycle, client contract, or blast radius.

Most teams will eventually want both: coarse isolation by endpoint, fine-grained exposure by custom permission.
