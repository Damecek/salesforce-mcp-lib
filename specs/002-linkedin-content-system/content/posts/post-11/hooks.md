# Hooks: Post 11 — Salesforce Hosted MCP Goes GA — Where It Wins and Where salesforce-mcp-lib Remains Essential

**Topic**: 11 — Hosted MCP vs salesforce-mcp-lib

## 1. Pain-First

Your CI/CD pipeline needs to call Salesforce MCP tools. Salesforce hosted MCP requires a user login via browser. There's no browser on your build server. Now what?

## 2. Misconception-First

"Salesforce launched hosted MCP — so salesforce-mcp-lib is dead." Not quite. Hosted MCP doesn't support service accounts, uses SSE-only transport, and ships pre-built SObject servers that give agents raw CRUD without business-logic guardrails. Different tools for different problems.

## 3. Architecture-First

Hosted MCP uses a dedicated `mcp_api` OAuth scope — the token can only reach MCP endpoints. salesforce-mcp-lib uses the standard `api` scope — broader access, wider blast radius. Same Salesforce security model underneath, but different trust boundaries at the token level.

## 4. Business-First

Salesforce hosted MCP servers go from Setup to connected agent in 30 minutes. For standard CRUD and Tableau access, that's the right choice. For service accounts, explicit tool boundaries, and custom deployment topologies — salesforce-mcp-lib fills the gaps hosted doesn't cover.

## 5. Curiosity-First

What happens when the platform vendor ships a hosted version of the protocol your open-source project implements? You find out exactly where the boundaries are — and they're more interesting than you'd expect.
