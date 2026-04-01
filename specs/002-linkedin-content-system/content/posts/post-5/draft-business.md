# Post 5 — Business: From Zero to AI-Enabled Org in 30 Lines of Apex
**Topic**: 5 — From Zero to AI-Enabled Org in 30 Lines of Apex
**Variant**: Business
**Word count**: 258
**Claims referenced**: [C-012, C-021, C-013, C-020]
---

The fastest way to kill an AI initiative is a long setup process. By the time the middleware is licensed, the sandbox is provisioned, and the integration is configured, the executive sponsor has moved on to the next priority.

Salesforce MCP Library was designed around a different assumption: if your team can't evaluate it in an afternoon, the framework has failed -- not your team.

Here's what "an afternoon" actually looks like. A developer clones the repo, deploys the minimal example with a single CLI command -- `sf project deploy start` -- and connects it to an AI agent using `npx salesforce-mcp-lib`. No middleware procurement. No external dependencies to install -- the npm package has zero production dependencies and requires only Node.js 20 or higher. The total Apex code for a working endpoint is 12 lines.

That 12-line endpoint isn't a toy. It inherits your org's existing security model -- OAuth scopes, Profiles, Permission Sets, Sharing Rules -- from the moment it deploys. The AI agent operates under the same authorization your users have today.

For teams ready to go deeper, the E2E example registers all three MCP capability types in a single endpoint: a SOQL query tool, an org metadata resource, and a dynamic prompt. That's the path from proof-of-concept to production pattern in a single repo.

The real business case isn't the framework itself. It's how fast your team can answer the question: "Can AI agents work with our Salesforce data securely?"

Deploy the minimal example to a scratch org and find out. The repo link is in the comments.
