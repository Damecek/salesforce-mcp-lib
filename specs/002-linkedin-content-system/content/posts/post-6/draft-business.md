# Post 6 — Business: Salesforce Has a New Interface — This One Is for AI Agents

**Topic**: 6 — Salesforce Has a New Interface — This One Is for AI Agents
**Variant**: Business
**Word count**: 224
**Claims referenced**: C-001, C-014, C-013

---

Your Salesforce org has years of accumulated business logic — screen flows for data entry, SOQL queries for reporting, validation rules for data quality, approval processes for compliance. Every one was built for humans interacting through a browser.

Now your AI agents need the same access. The typical response? Build custom REST endpoints. Write middleware. Replicate data into a vector store. Each approach means duplicating logic that already works, creating new security surfaces, and maintaining parallel systems.

There's a simpler path. `salesforce-mcp-lib` wraps existing Salesforce logic into tools that AI agents discover and call through the Model Context Protocol. A SOQL query that powers a record page becomes a tool an agent calls with `tools/call`. A subflow that a screen flow invokes for data entry becomes a tool an agent triggers with validated JSON parameters.

The business logic stays exactly where it is — in your org, tested, governed, audited. You're not moving data out. You're not rebuilding processes. You're adding a new interface that MCP-compatible agents — Claude, GPT, Copilot — can use to interact with what you already built.

Security isn't an afterthought: agents operate under the same profiles, permission sets, and sharing rules as your users. Three of four authorization layers are platform-enforced, not custom code.

Look at the screen flows your team built last quarter. Each one could be an AI agent capability — without rewriting a line of business logic.
