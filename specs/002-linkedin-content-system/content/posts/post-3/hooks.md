# Hooks: Post 3 — Zero Dependencies, Two Layers, Full Protocol — Inside the Architecture

**Topic**: 3 — Zero Dependencies, Two Layers, Full Protocol — Inside the Architecture

---

## 1. Pain-first

Your AI integration has 47 transitive dependencies, and you've audited exactly none of them.
Last quarter a single npm package update broke three production pipelines.
There's a simpler number to manage: zero.

## 2. Misconception-first

"Minimal dependencies" is not the same as zero dependencies.
Minimal still means a `node_modules` folder, a lock file, and a supply-chain you don't fully control.
Salesforce MCP Library ships 77 Apex classes and 6 TypeScript modules with no external production packages on either side.

## 3. Architecture-first

Two layers. One stateless, one stateful. Zero shared dependencies between them.
The Apex server rebuilds per request inside governor limits; the TypeScript proxy owns OAuth, transport, and session state.
That boundary exists because Salesforce and Node.js are good at different things — and the architecture respects both.

## 4. Business-first

Every production dependency is a line item in your next security audit.
Every transitive package is a breaking change you can't predict.
Salesforce MCP Library eliminated that entire category of operational risk — zero external dependencies on both layers.

## 5. Curiosity-first

What happens when you implement a full protocol server — JSON-RPC 2.0, MCP 2025-11-25, OAuth, batch requests — without importing a single external package?
You get 77 Apex classes and 6 TypeScript modules that use only platform-native APIs.
And a `node_modules` folder that doesn't exist.
