# Post 2 — Technical: The Hidden Cost of "Just Build an API" for AI Integration
**Topic**: 2 — The Hidden Cost of "Just Build an API" for AI Integration
**Variant**: Technical
**Word count**: 276
**Claims referenced**: C-002, C-007, C-008, C-014
---

"Just build a REST API" is the most expensive sentence in enterprise AI integration.

Here's what actually happens. Team A builds a custom endpoint for an AI agent to query Accounts. Team B builds another for Cases. Team C adds one for Opportunities with different auth. Six months later, you have 40 endpoints, three credential stores, no capability discovery, and an AI agent that can't tell you what it's allowed to do.

The core problem isn't the endpoint. It's that REST APIs are invisible to agents. An LLM can't ask a REST endpoint "what tools do you have?" or "what parameters does this accept?" Every integration requires hardcoded knowledge that breaks the moment someone renames a field.

This is the architectural problem MCP solves. In our Salesforce MCP Library, the initialize handler dynamically advertises only the capabilities that are actually registered -- tools, resources, or prompts. If a tool isn't registered, the agent never sees it. No stale documentation, no phantom endpoints.

When an agent calls a tool, the two-tier error model separates protocol failures from tool failures. A malformed request returns a JSON-RPC error. A validation failure in your Apex logic returns a successful response with `isError: true`. The agent can distinguish "I sent a bad request" from "the tool ran but rejected my input" -- and adjust accordingly.

Layer this on top of Salesforce's four-tier authorization model -- OAuth scopes, Profiles, Sharing Rules, and your custom validation logic -- and every tool call runs inside a security perimeter that already exists.

Count your current custom endpoints. Now ask: can any of them tell an AI agent what they do?

That's the audit worth running.
