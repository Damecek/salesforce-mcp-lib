# Post 1 — Business: Your Salesforce Org Already Speaks AI — It Just Needs a Protocol

**Topic**: 1 — Your Salesforce Org Already Speaks AI — It Just Needs a Protocol
**Variant**: Business
**Word count**: 237
**Claims referenced**: [C-001, C-012, C-022]

---

Your team is probably building AI integrations the expensive way — extracting Salesforce data into middleware, maintaining custom REST endpoints, and managing credentials across systems. Every new AI tool means another integration to build and secure.

There's a simpler approach. The Model Context Protocol (MCP) is an open standard that lets AI agents discover and use capabilities directly where the data lives. Instead of pulling records out of Salesforce and feeding them to a model, the agent connects, sees what tools are available, and executes them — all within your org's existing security model.

Salesforce MCP Library makes this work natively in Apex. No middleware to license. No data leaving your security perimeter. No external dependencies to audit — the entire stack of 77 Apex classes and 6 TypeScript modules runs on platform-native APIs only.

The practical impact: a complete MCP endpoint requires 12 lines of Apex. Your team can go from "what is this?" to a working prototype in a single afternoon. That prototype already inherits your org's profiles, permission sets, and sharing rules — the same security your users operate under today.

This matters for planning because every AI agent that connects through MCP uses the same protocol. Build the endpoint once, and it works with Claude, with custom agents, with whatever your team adopts next year.

Explore the minimal example in the repo to see what 12 lines of Apex gets you. The repo link is in the comments.
