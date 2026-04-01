---
marp: true
theme: linkedin
paginate: true
---

# Every Dependency Is a Liability

Your AI integration stack carries hidden costs.

License audits. Security reviews. Version conflicts surfacing at 2 AM.

Every external package is risk you have to manage.

---

## What If the Answer Were Zero?

Salesforce MCP Library connects AI agents to Salesforce orgs with **zero production dependencies** on either side.

No npm packages. No external Apex libraries. Everything is implemented in-repo.

---

## The Apex Layer — 77 Classes, No Imports

The Apex server implements the entire **JSON-RPC 2.0** protocol natively — all five standard error codes and batch request support.

No managed packages. Fully auditable.

---

## The TypeScript Proxy — Built-Ins Only

Six modules handle OAuth, token lifecycle, and transport using only **Node.js built-in APIs**.

Zero npm production dependencies. Nothing to audit beyond your own code.

---

## Three Risk Categories Eliminated

No **supply-chain vulnerabilities** from transitive dependencies.

No **breaking changes** from third-party releases.

No **license compliance reviews** for production code you didn't write.

---

## Clean Separation, Independent Teams

The proxy owns all session state — auth tokens, transport, error translation.

Apex stays **stateless per request**.

Your Salesforce team and platform team work independently without conflicts.

---

# Explore the Architecture

Zero production dependencies. One repo to audit. Two layers with a clean boundary.

Check out the wire-contract audit to see how every protocol method maps to the implementation.

**⭐ github.com/damecek/salesforce-mcp-lib**
