# Derivatives: Post 2 — The Hidden Cost of "Just Build an API" for AI Integration

**Source variant**: business
**Generated**: 2026-04-01

## Short Post
**Word count**: 87 (max: 100)

Every custom REST endpoint you build for AI integration becomes a permanent maintenance line item.

Within a quarter most orgs have a dozen endpoints, scattered credentials, and nobody who can explain what the AI agent is actually authorized to do. The hidden cost isn't v1 — it's v47.

MCP changes the model entirely. With Salesforce MCP Library, the server dynamically advertises only registered capabilities. Agents discover what's available at runtime.

Count your existing integration endpoints. The number will make the case for you.

## Carousel Script
**Slides**: 7 (target: 5–8)

### Slide 1: The Integration Endpoint Trap
Every custom REST endpoint you build for AI integration is a maintenance line item your team carries forever. It starts with one. Then another team needs write access with different auth. Before you know it — a dozen endpoints, credentials everywhere, no clear picture of what the agent can actually do.

### Slide 2: The Real Cost Is Not V1
Building the first endpoint is easy. Maintaining the 47th — when three teams are adding tools and nobody owns the integration layer — that's where the cost lives. And it compounds every quarter.

### Slide 3: The Discovery Problem
Custom endpoints don't support capability discovery. An AI agent can't ask "what can I do here?" Someone has to manually map every action, every parameter, every permission. That mapping breaks the moment a field name changes.

### Slide 4: MCP Eliminates the Category
MCP replaces this entire pattern. Instead of static endpoints, the server dynamically advertises only the capabilities you've registered. Agents discover what's available at runtime — no manual mapping needed.

### Slide 5: Auth That Already Exists
Every request runs through Salesforce's existing four-layer authorization: OAuth scopes, Profiles, Permission Sets, and Sharing Rules. No new credential stores. No middleware. No data leaving the org.

### Slide 6: Transparent Session Handling
When a Salesforce session expires, the proxy transparently re-authenticates. The agent never sees the failure. No retry logic to build. No token refresh endpoints to maintain.

### Slide 7: Start With a Simple Audit — CTA
Before building your next AI integration endpoint, count the ones you already have. Then count the credential stores backing them. The result will make the case for you. Check out Salesforce MCP Library to see the alternative.

## Comment Version
**Sentences**: 3 (target: 2–3)

The biggest cost of custom AI integration endpoints isn't building them — it's maintaining the credential sprawl and manual capability mapping that comes with every new one. Most orgs I've seen can't even tell you what their AI agent is authorized to do across all their endpoints. Dynamic capability discovery through MCP is a fundamentally different model worth looking at.

## DM Explanation
**Sentences**: 5 (target: 3–5)

So you know how most teams build one-off REST endpoints whenever they need an AI agent to talk to Salesforce? That works fine the first time, but after a few quarters you end up with a dozen endpoints, credentials scattered everywhere, and nobody who really owns it. The core issue is that custom endpoints can't tell an agent what's available — someone has to manually document every action, and it goes stale immediately. What MCP does differently is the server dynamically advertises only the capabilities you've registered, so agents discover everything at runtime. It runs through Salesforce's existing auth layers too, so there's no new credential stores or middleware to deal with.

---
## Validation
- Short post word count: 87 (max: 100)
- Carousel slides: 7 (target: 5–8)
- Comment sentences: 3 (target: 2–3)
- DM sentences: 5 (target: 3–5)
- Core message preserved: YES
- Key repo fact preserved: YES
