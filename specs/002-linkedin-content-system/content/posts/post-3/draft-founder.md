# Post 3 — Founder: Zero Dependencies, Two Layers, Full Protocol — Inside the Architecture

**Topic**: 3 — Zero Dependencies, Two Layers, Full Protocol — Inside the Architecture
**Variant**: Founder
**Word count**: 261
**Claims referenced**: [C-004, C-005, C-006, C-009, C-022]

---

I made a decision early in building Salesforce MCP Library that some people thought was stubborn: zero external dependencies. Not on the Apex side. Not on the TypeScript side. Not anywhere.

The reasoning was simple. If you're building a protocol server that enterprises will deploy inside their Salesforce security perimeter, every dependency is a trust decision you're making on behalf of someone else's org. I didn't want to make those decisions. I wanted the entire stack — 77 Apex classes, 6 TypeScript modules — to be readable and auditable in one place.

So we implemented JSON-RPC 2.0 from scratch. All five standard error codes. Batch request arrays with empty-batch rejection and notification handling. The TypeScript proxy uses only Node.js built-ins — `node:https`, `node:http`, `node:readline`, `node:url` — for OAuth, stdio transport, and error translation across five categories of Salesforce HTTP responses.

The two-layer split came from respecting what each platform is good at. Salesforce is great at data, permissions, and business logic — but it's stateless per request by design. Node.js is great at holding connections open and managing token lifecycle. So the proxy owns session state, and the Apex endpoint rebuilds cleanly every time. Neither layer pretends to be something it isn't.

Was it more work than importing a JSON-RPC library? Yes. Do I sleep better knowing there's no `node_modules` folder and no transitive dependency that could break production on a Friday afternoon? Also yes.

Check out the wire-contract audit in the repo — every protocol method is traced end to end.
