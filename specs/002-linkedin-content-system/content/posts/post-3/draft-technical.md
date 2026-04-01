# Post 3 — Technical: Zero Dependencies, Two Layers, Full Protocol — Inside the Architecture

**Topic**: 3 — Zero Dependencies, Two Layers, Full Protocol — Inside the Architecture
**Variant**: Technical
**Word count**: 272
**Claims referenced**: [C-004, C-005, C-006, C-009, C-022]

---

The best protocol implementation is the one with zero dependencies. Not "minimal" dependencies — zero.

Salesforce MCP Library implements the full JSON-RPC 2.0 and MCP 2025-11-25 specifications across two layers, and neither layer imports a single external production dependency. Here's why that design exists and how it works.

The Apex layer is 77 classes. It implements the complete JSON-RPC 2.0 spec in-repo — including all five standard error codes (-32700 through -32603), batch request support, empty-batch rejection, and all-notification response suppression. Every request rebuilds the server from scratch inside Salesforce governor limits. No persistent state. No session objects. No cross-request cleanup. The stateless design isn't a compromise — it's how you build a reliable protocol server on a platform with strict execution boundaries.

The TypeScript layer is 6 modules using only Node.js built-in APIs (`node:https`, `node:http`, `node:readline`, `node:url`). It owns everything the Apex layer deliberately ignores: OAuth 2.0 token lifecycle, MCP stdio transport, and session state. When Salesforce returns an HTTP 401 with INVALID_SESSION_ID, the proxy re-authenticates and retries once — transparently. When the org throws an APEX_ERROR, the proxy translates it to a JSON-RPC -32603 with a sanitized message. Five HTTP response categories are mapped to proper error codes so AI agents never see raw Salesforce errors.

The proxy owns state. Apex stays stateless. JSON-RPC lives in-repo. There's nothing in `node_modules`, nothing in external Apex packages, and nothing that can break when a transitive dependency ships a bad release on a Friday afternoon.

Read the wire-contract audit in the repo to trace exactly how every MCP method maps through both layers.
