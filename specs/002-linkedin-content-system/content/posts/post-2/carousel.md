---
marp: true
theme: linkedin
paginate: true
---

# The Integration Endpoint Trap

Every custom REST endpoint you build for AI integration is a maintenance line item your team carries forever.

It starts with one. Then three teams need access. Before you know it — a dozen endpoints, credentials everywhere.

---

## The Real Cost Is Not V1

Building the first endpoint is easy.

Maintaining the **47th** — when three teams are adding tools and nobody owns the integration layer — that's where the cost lives.

And it compounds every quarter.

---

## The Discovery Problem

Custom endpoints don't support capability discovery.

An AI agent can't ask **"what can I do here?"**

Someone has to manually map every action, every parameter, every permission. That mapping breaks the moment a field name changes.

---

## MCP Eliminates the Category

Instead of static endpoints, the server **dynamically advertises** only the capabilities you've registered.

Agents discover what's available at runtime — no manual mapping needed.

---

## Auth That Already Exists

Every request runs through Salesforce's existing four-layer authorization:

**OAuth scopes → Profiles → Permission Sets → Sharing Rules**

No new credential stores. No middleware. No data leaving the org.

---

## Transparent Session Handling

When a Salesforce session expires, the proxy transparently re-authenticates.

The agent **never sees the failure**.

No retry logic to build. No token refresh endpoints to maintain.

---

# Start With a Simple Audit

Count your existing AI integration endpoints. Then count the credential stores backing them.

The result will make the case for you.

**⭐ github.com/damecek/salesforce-mcp-lib**
