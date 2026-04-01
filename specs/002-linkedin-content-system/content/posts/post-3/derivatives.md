# Derivatives: Post 3 — Zero Dependencies, Two Layers, Full Protocol — Inside the Architecture

**Source variant**: business
**Generated**: 2026-04-01

## Short Post
**Word count**: 88 (max: 100)

Every dependency in your AI integration stack is a liability. License audits. Security reviews. Breaking changes at 2 AM.

Salesforce MCP Library takes a different approach: zero production dependencies on both sides. The Apex layer — 77 classes — implements the full JSON-RPC 2.0 protocol in-repo. The TypeScript proxy uses only Node.js built-ins. No supply-chain risk. No third-party breaking changes. No license reviews for code you didn't write. One repo to audit. Two layers. Zero external packages.

## Carousel Script
**Slides**: 7 (target: 5–8)

### Slide 1: Every Dependency Is a Liability
Your AI integration stack carries hidden costs. License audits. Security reviews. Version conflicts surfacing at 2 AM. Every external package is risk you have to manage.

### Slide 2: What If the Answer Were Zero?
Salesforce MCP Library connects AI agents to Salesforce orgs with zero production dependencies on either side. No npm packages. No external Apex libraries. Everything is implemented in-repo.

### Slide 3: The Apex Layer — 77 Classes, No Imports
The Apex server implements the entire JSON-RPC 2.0 protocol natively — all five standard error codes and batch request support. No managed packages. Fully auditable.

### Slide 4: The TypeScript Proxy — Built-Ins Only
Six modules handle OAuth, token lifecycle, and transport using only Node.js built-in APIs. Zero npm production dependencies. Nothing to audit beyond your own code.

### Slide 5: Three Risk Categories Eliminated at Once
No supply-chain vulnerabilities from transitive dependencies. No breaking changes from third-party releases. No license compliance reviews for production code you didn't write.

### Slide 6: Clean Separation, Independent Teams
The proxy owns all session state — auth tokens, transport, error translation. Apex stays stateless per request. Your Salesforce team and platform team work independently without conflicts.

### Slide 7: Explore the Architecture Yourself
Zero production dependencies. One repo to audit. Two layers with a clean boundary. Check out the wire-contract audit in the repo to see how every protocol method maps to the implementation.

## Comment Version
**Sentences**: 3 (target: 2–3)

The hardest part of maintaining AI integrations isn't the code you write — it's the code you import. We built our Salesforce MCP connector with zero production dependencies on both the Apex and TypeScript sides, implementing the full JSON-RPC 2.0 protocol in-repo. One repository, two layers, and nothing you didn't write yourself to audit.

## DM Explanation
**Sentences**: 4 (target: 3–5)

So we built this Salesforce MCP connector and deliberately went with zero external dependencies on both sides — no npm packages, no managed Apex packages, nothing. The Apex layer is 77 classes that implement the full JSON-RPC 2.0 protocol natively, and the TypeScript proxy only uses Node.js built-in APIs. The big win is you eliminate supply-chain risk, breaking changes from third parties, and license headaches all at once. It's basically one repo to audit with a clean split between a stateless Apex layer and a proxy that handles all the session stuff.

---
## Validation
- Short post word count: 88 (max: 100)
- Carousel slides: 7 (target: 5–8)
- Comment sentences: 3 (target: 2–3)
- DM sentences: 4 (target: 3–5)
- Core message preserved: YES
- Key repo fact preserved: YES
