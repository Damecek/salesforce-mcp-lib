# Post 3 — Business: Zero Dependencies, Two Layers, Full Protocol — Inside the Architecture

**Topic**: 3 — Zero Dependencies, Two Layers, Full Protocol — Inside the Architecture
**Variant**: Business
**Word count**: 253
**Claims referenced**: [C-004, C-005, C-009, C-020, C-022]

---

Every dependency your AI integration stack carries is a liability your team has to manage. License audits. Security reviews. Breaking changes from packages you don't control. Version conflicts that surface at 2 AM.

What if the answer were zero?

Salesforce MCP Library connects AI agents to Salesforce orgs using a two-layer architecture where neither layer depends on external production packages. The Apex server — 77 classes — implements the entire JSON-RPC 2.0 protocol in-repo, including all five standard error codes and batch request support. The TypeScript proxy — 6 modules, zero npm production dependencies — handles OAuth, token lifecycle, and transport using only Node.js built-in APIs.

For engineering teams, this design eliminates three categories of operational risk at once. No supply-chain vulnerabilities from transitive dependencies. No breaking changes when a third-party package pushes a release. No license compliance reviews for production code you didn't write. The entire protocol stack is auditable in a single repository.

The architecture also eliminates a coordination problem. The proxy owns all session state — authentication tokens, MCP transport, error translation across five Salesforce HTTP response categories. The Apex layer stays completely stateless per request. That separation means your Salesforce team and your platform team can work on their respective layers without stepping on each other.

Zero production dependencies on both sides. One repo to audit. Two layers with a clean boundary between them.

Explore the wire-contract audit in the repo to see how every protocol method maps to the implementation.
