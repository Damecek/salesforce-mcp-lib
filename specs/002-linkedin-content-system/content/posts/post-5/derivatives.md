# Derivatives: Post 5 — From Zero to AI-Enabled Org in 30 Lines of Apex

**Source variant**: business
**Generated**: 2026-04-01

## Short Post
**Word count**: 72 (max: 100)

Most AI-on-Salesforce projects stall before anyone writes code. Licensing, middleware, sandbox provisioning -- the sponsor loses interest before the first demo.

Salesforce MCP Library takes a different path. Clone the repo, deploy with one CLI command, connect an AI agent. Twelve lines of Apex. Zero production dependencies. Full org security inherited on deploy.

If your team can't evaluate it in an afternoon, the framework failed.

## Carousel Script
**Slides**: 7 (target: 5–8)

### Slide 1: AI Projects Die in Setup
Most Salesforce AI initiatives stall before anyone writes a line of code. Middleware licensing, sandbox provisioning, and integration configuration drain momentum long before the first demo.

### Slide 2: What If Setup Took an Afternoon?
Salesforce MCP Library was built on one principle: if your team can't evaluate it in a single afternoon, the framework has failed -- not your team.

### Slide 3: One Command to Deploy
A developer clones the repo and runs `sf project deploy start`. No middleware procurement. No external dependencies. The npm package has zero production dependencies and needs only Node.js 20+.

### Slide 4: Twelve Lines of Working Apex
The minimal example is a fully functional MCP endpoint in just 12 lines of Apex. It's not a toy -- it's a real integration point for AI agents.

### Slide 5: Security Is Already Built In
That endpoint inherits your org's existing security model the moment it deploys. OAuth scopes, Profiles, Permission Sets, Sharing Rules -- all enforced automatically.

### Slide 6: From POC to Production Pattern
The E2E example registers all three MCP capability types in a single endpoint: a SOQL query tool, an org metadata resource, and a dynamic prompt. One repo covers the full path.

### Slide 7: Find Out This Afternoon — CTA
The real question isn't whether the framework works. It's how fast your team can answer: "Can AI agents access our Salesforce data securely?" Deploy to a scratch org and find out. Link in comments.

## Comment Version
**Sentences**: 3 (target: 2–3)

We built this because every AI-on-Salesforce project we saw was dying in the setup phase, not the implementation phase. The entire working endpoint is 12 lines of Apex with zero external dependencies. If anyone's tried connecting agents to their org, I'd love to hear what the setup experience was like.

## DM Explanation
**Sentences**: 4 (target: 3–5)

So we open-sourced a library that lets you connect AI agents to Salesforce without any middleware or external dependencies. The whole setup is basically one CLI command and about 12 lines of Apex for a working endpoint. It uses your org's existing security model so you don't have to configure separate auth. Honestly the main selling point is that a developer can evaluate the whole thing in an afternoon instead of waiting weeks for procurement.

---
## Validation
- Short post word count: 72 (max: 100)
- Carousel slides: 7 (target: 5–8)
- Comment sentences: 3 (target: 2–3)
- DM sentences: 4 (target: 3–5)
- Core message preserved: YES
- Key repo fact preserved: YES
