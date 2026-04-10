# Hooks: Post 9 - The Proxy Is Optional. Transport and Token Ownership Are Not

**Topic**: 9 - The Proxy Is Optional. Transport and Token Ownership Are Not

## 1. Pain-First

People see the proxy in a Salesforce MCP setup and assume it is unnecessary infrastructure.
Usually what they really mean is that they want the auth and transport complexity to live somewhere else.

## 2. Misconception-First

"No proxy" sounds simpler.
In practice it often means "the proxy logic moved into my workflow tool, my host config, or my custom integration code."

## 3. Architecture-First

The repo keeps the split clean: Apex is the stateless MCP server, TypeScript owns OAuth, token caching, session retry, and transport bridging for stdio-based hosts.

## 4. Business-First

If your orchestration platform can talk directly to the remote MCP endpoint, skipping the proxy can reduce deployment friction.
But someone still has to own token refresh, bearer propagation, and session-failure behavior.

## 5. Curiosity-First

What if the proxy is not the important architectural decision at all?
What if the real decision is which layer should own auth state and transport compatibility for the agent session?
