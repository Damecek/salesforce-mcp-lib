---
marp: true
theme: linkedin
paginate: true
---

# AI Projects Die in Setup

Most Salesforce AI initiatives stall before anyone writes a line of code.

Middleware licensing, sandbox provisioning, and integration configuration drain momentum long before the first demo.

---

## What If Setup Took an Afternoon?

Salesforce MCP Library was built on one principle:

**If your team can't evaluate it in a single afternoon, the framework has failed — not your team.**

---

## One Command to Deploy

A developer clones the repo and runs:

`sf project deploy start`

No middleware procurement. No external dependencies. The npm package has **zero production dependencies** and needs only Node.js 20+.

---

## Twelve Lines of Working Apex

The minimal example is a fully functional MCP endpoint in just **12 lines of Apex**.

It's not a toy — it's a real integration point for AI agents.

---

## Security Is Already Built In

That endpoint inherits your org's existing security model the moment it deploys.

**OAuth scopes, Profiles, Permission Sets, Sharing Rules** — all enforced automatically.

---

## From POC to Production Pattern

The E2E example registers all three MCP capability types in a single endpoint:

A **SOQL query tool**, an **org metadata resource**, and a **dynamic prompt**.

One repo covers the full path.

---

# Find Out This Afternoon

The real question isn't whether the framework works. It's how fast your team can answer: "Can AI agents access our Salesforce data securely?"

Deploy to a scratch org and find out.

**⭐ github.com/damecek/salesforce-mcp-lib**
