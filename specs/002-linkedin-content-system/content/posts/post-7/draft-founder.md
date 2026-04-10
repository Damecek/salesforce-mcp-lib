# Post 7 - Founder: Watching the PoC Confirm the Exact Problem We Built For

**Topic**: 7 - Watching the PoC Confirm the Exact Problem We Built For
**Variant**: Founder
**Word count**: 200
**Claims referenced**: [C-001, C-011, C-014]

---

What I liked about that LinkedIn post is that it showed the problem honestly.

The agent was not broken. It was trying to solve a Salesforce task with a toolset that knew Salesforce only in generic terms. So it searched, retried, expanded scope, and eventually brute-forced its way to the right record. Mission accomplished, but in the least elegant way possible.

That is exactly the gap I wanted `salesforce-mcp-lib` to address.

Salesforce orgs are full of business-specific operations, but most agent integrations expose only generic access. Search. Query. Update. Create. The repo goes the other direction: you define the operations explicitly in Apex, register them on `McpServer`, and expose the verbs the business actually uses. The platform still enforces profiles, permission sets, sharing rules, and the rest of the security model you already trust.

That difference sounds small until you see it in practice. When the agent gets a tool that matches the real task, it stops treating your org like an unknown database and starts acting more like a team member with context.

The biggest takeaway from the PoC was not "AI can do Salesforce now."

It was: the shape of the tools matters more than the raw access.
