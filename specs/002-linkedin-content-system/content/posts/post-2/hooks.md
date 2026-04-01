# Hooks: Post 2 — The Hidden Cost of "Just Build an API" for AI Integration
**Topic**: 2 — The Hidden Cost of "Just Build an API" for AI Integration
---

## 1. Pain-first

Your AI agent can't tell you what it's allowed to do in Salesforce. That's because your 15 custom REST endpoints don't support capability discovery -- every integration is hardcoded knowledge that breaks the moment someone renames a field.

## 2. Misconception-first

"Just build a REST API" sounds like the pragmatic choice. But every custom endpoint is a capability that no AI agent can discover on its own, a credential that needs rotating, and a mapping that rots the moment the org changes. The real cost isn't building it -- it's maintaining it at scale.

## 3. Architecture-first

We implemented a two-tier error model where protocol failures and tool failures return different response types. It sounds like a minor design decision -- until you realize it's the reason an AI agent can distinguish "my request was malformed" from "the tool rejected my input" and adjust without human intervention.

## 4. Business-first

Three teams, 40 custom endpoints, credentials in four different stores, and a Confluence page nobody trusts. That's the actual cost of "just build an API" for AI integration -- not the first endpoint, but the fortieth, maintained by people who didn't build the first.

## 5. Curiosity-first

What happens when an AI agent needs to know what tools are available in your Salesforce org? With custom REST endpoints, the answer is: someone maintains a list. With MCP, the server advertises registered capabilities at runtime -- the agent asks, and the protocol answers.
