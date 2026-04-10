# Post 7 - Technical: Generic Salesforce Access Is Not the Same as Agent-Usable Operations

**Topic**: 7 - Generic Salesforce Access Is Not the Same as Agent-Usable Operations
**Variant**: Technical
**Word count**: 213
**Claims referenced**: [C-007, C-011, C-013, C-014]

---

The interesting part of the Dust PoC wasn't that the agent failed. It was that the tool surface was too generic for the job.

If an agent needs to update one Account, "search Salesforce" is not a business operation. It is a broad capability with too much ambiguity, too little domain context, and too many ways to burn query limits. That is exactly where generic connectors start to look like middleware with nicer branding.

`salesforce-mcp-lib` takes a different approach. The endpoint is just Apex code that instantiates `McpServer`, registers explicit tools, and delegates to `handleRequest()`. The framework then advertises only the capabilities that were actually registered. In the repo, the e2e example wires a tool, a resource, and a prompt into one Apex REST endpoint in a few lines.

That design matters because it lets you publish operations the agent can reason about: `find_account_for_renewal`, `update_billing_contact`, `create_partner_case`. Not "go explore my CRM and improvise."

The security model stays native to Salesforce: OAuth scopes, profiles, permission sets, sharing rules, then any tool-specific checks you add in `validate()` or `execute()`.

The improvement in the PoC was not more model intelligence. It was better verbs.

That is the pattern I would optimize for: make the tool name match the business operation, and let the agent stop guessing.
