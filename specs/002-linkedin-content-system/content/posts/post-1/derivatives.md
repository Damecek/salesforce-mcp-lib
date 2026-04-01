# Derivatives: Post 1 — Your Salesforce Org Already Speaks AI — It Just Needs a Protocol

**Source variant**: business
**Generated**: 2026-04-01

## Short Post

**Word count**: 88 (max: 100)

Your team is building AI integrations the expensive way — middleware, custom endpoints, credential sprawl. Every new AI tool means another integration.

Model Context Protocol changes that. MCP lets AI agents discover and use tools directly inside Salesforce, within your existing security model.

Salesforce MCP Library makes it native Apex. No middleware. No data leaving your perimeter. 77 Apex classes, zero external dependencies — and a complete MCP endpoint takes 12 lines of Apex.

Build once, connect any AI agent. Repo link in comments.

## Carousel Script

**Slides**: 7 (target: 5–8)

### Slide 1: Your AI Integrations Are Costing Too Much
Most teams connect AI to Salesforce the hard way — extracting data into middleware, building custom REST endpoints, managing credentials across systems. Every new AI tool means another integration to build and secure.

### Slide 2: There's an Open Standard for This
The Model Context Protocol (MCP) lets AI agents discover and use capabilities directly where the data lives. No extraction. No middleware. The agent connects, sees available tools, and executes them.

### Slide 3: Native Apex, Zero External Dependencies
Salesforce MCP Library runs entirely on platform-native APIs. 77 Apex classes and 6 TypeScript modules — nothing to license, nothing leaving your security perimeter, nothing external to audit.

### Slide 4: 12 Lines of Apex to a Working Endpoint
A complete MCP endpoint requires just 12 lines of Apex. Your team can go from "what is this?" to a working prototype in a single afternoon.

### Slide 5: Your Security Model Already Applies
The prototype inherits your org's profiles, permission sets, and sharing rules automatically. No extra security configuration — the same controls your users operate under today.

### Slide 6: Build Once, Connect Any AI Agent
Every agent that connects through MCP uses the same protocol. Build the endpoint once, and it works with Claude, with custom agents, with whatever your team adopts next year.

### Slide 7: See It in Action — Check the Repo
Explore the minimal example to see what 12 lines of Apex gets you. The repo link is in the comments. Start with a prototype this afternoon.

## Comment Version

**Sentences**: 3 (target: 2–3)

This resonates — the integration sprawl with AI tooling is real, especially in Salesforce orgs. We've been working on an open-source Apex library that exposes Salesforce capabilities through MCP so AI agents connect directly, no middleware needed. A full endpoint is 12 lines of Apex and inherits the org's existing security model, which has been the biggest unlock for getting teams past the prototype stage.

## DM Explanation

**Sentences**: 4 (target: 3–5)

Hey — so you know how connecting AI tools to Salesforce usually means building middleware, custom APIs, the whole mess? We built an open-source Apex library that lets AI agents talk directly to your org using Model Context Protocol, which is basically a standard way for agents to discover and call tools. The whole thing is 77 Apex classes with zero external dependencies, and you can stand up a working endpoint in like 12 lines of code. It runs inside your org's security model so there's no data leaving the perimeter, which makes the compliance conversation way easier.

---

## Validation

- Short post word count: 88 (max: 100)
- Carousel slides: 7 (target: 5–8)
- Comment sentences: 3 (target: 2–3)
- DM sentences: 4 (target: 3–5)
- Core message preserved: YES
- Key repo fact preserved: YES
