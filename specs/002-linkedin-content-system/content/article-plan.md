# Article Plan: Building an MCP Server Inside Salesforce — Zero Dependencies, Full Protocol, Native Apex

**Generated**: 2026-04-01
**Source**: Repository analysis of salesforce-mcp-lib
**Repo**: https://github.com/damecek/salesforce-mcp-lib

## Metadata

- **Title**: Building an MCP Server Inside Salesforce — Zero Dependencies, Full Protocol, Native Apex
- **Subtitle**: How we implemented the Model Context Protocol natively in Apex so AI agents can talk to Salesforce without middleware, without data extraction, and without a single external dependency.
- **Target word count**: 2200
- **Target audience**: Salesforce developers and architects / Engineering managers evaluating AI integration approaches
- **SEO keywords**: MCP Salesforce, Model Context Protocol Apex, Salesforce AI agent integration, MCP server framework, Apex REST AI, zero dependency MCP, Salesforce MCP library, JSON-RPC Apex
- **Hashtags**: #Salesforce #MCP #OpenSource #Apex #AIAgents #EnterpriseAI

## Section 1: The Problem — Why Every AI-to-Salesforce Integration Looks the Same

- **Purpose**: Hook the reader by naming a pattern they recognize — and the pain it causes.
- **Target words**: 250
- **Key points**:
  - Teams build custom REST endpoints to let AI agents access Salesforce data — each one bespoke, each one a maintenance liability
  - Common pattern: extract data out of Salesforce → transform → feed to model. Problems: stale data, credential sprawl, no capability discovery
  - No AI agent can ask a custom REST endpoint "what can you do?" — capabilities are invisible without manual mapping
  - The real cost isn't building integration v1, it's maintaining v47 when three teams are adding tools
- **Claims**: C-007, C-014
- **Repo links**:
  - https://github.com/damecek/salesforce-mcp-lib/blob/main/docs/mcp-authorization-feasibility-report-2026-03-22.md
- **Code snippet**: No

## Section 2: What MCP Is — And Why It Matters for Salesforce

- **Purpose**: Establish context — explain the Model Context Protocol and why it's a better model for AI-to-Salesforce communication.
- **Target words**: 300
- **Key points**:
  - MCP (Model Context Protocol) is an open standard for AI agents to discover and invoke external capabilities — like USB-C for AI integrations
  - Three capability types: tools (execute actions), resources (read data), prompts (template generation)
  - The protocol uses JSON-RPC 2.0 over stdio — agents connect, call `initialize`, discover capabilities via `tools/list`, then invoke them via `tools/call`
  - Salesforce MCP Library implements the full MCP 2025-11-25 spec — all 11 protocol methods, wire-format verified
  - Four protocol versions supported (backward-compatible negotiation): 2025-11-25, 2025-06-18, 2025-03-26, 2024-11-05
- **Claims**: C-001, C-002, C-003
- **Repo links**:
  - https://github.com/damecek/salesforce-mcp-lib/blob/main/docs/mcp-wire-contract-audit-2025-11-25.md
  - https://github.com/damecek/salesforce-mcp-lib/blob/main/specs/001-apex-mcp-server/spec.md
- **Code snippet**: No

## Section 3: Architecture — Two Layers, Zero Dependencies

- **Purpose**: Walk through the technical design — how a stateless Apex server and a stateful TypeScript proxy work together.
- **Target words**: 400
- **Key points**:
  - Two-layer architecture: stateless Apex server (rebuilds per request inside governor limits) + stateful TypeScript stdio proxy (owns session state, handles OAuth, transport)
  - Why stateless Apex: Salesforce `@RestResource` endpoints are synchronous and have no cross-request memory — the design works WITH this constraint
  - The proxy handles: OAuth 2.0 client credentials flow, token caching, automatic 401 re-authentication (single retry), error sanitization, secret redaction in logs
  - JSON-RPC 2.0 implemented in-repo (14 classes) — not imported from any library. All 5 standard error codes, batch request support, notification handling
  - MCP layer: 40 Apex classes for the full protocol — initialize, capability advertisement, tools/resources/prompts handlers
  - Zero external dependencies on BOTH sides: Apex uses `JSON.deserializeUntyped()` and platform APIs only; TypeScript uses `node:https`, `node:http`, `node:readline`, `node:url` only
  - Request flow: AI agent → stdio → TypeScript proxy → HTTP + Bearer token → Apex `@RestResource` → McpServer → JSON-RPC dispatch → handler → response
- **Claims**: C-004, C-005, C-006, C-009, C-022
- **Repo links**:
  - https://github.com/damecek/salesforce-mcp-lib/blob/main/force-app/main/json-rpc/classes/JsonRpcServiceRuntime.cls
  - https://github.com/damecek/salesforce-mcp-lib/blob/main/force-app/main/mcp/classes/McpJsonRpcModuleBuilder.cls
  - https://github.com/damecek/salesforce-mcp-lib/blob/main/packages/salesforce-mcp-lib/src/mcpBridge.ts
  - https://github.com/damecek/salesforce-mcp-lib/blob/main/packages/salesforce-mcp-lib/src/oauth.ts
  - https://github.com/damecek/salesforce-mcp-lib/blob/main/specs/001-apex-mcp-server/plan.md
- **Code snippet**: Yes — excerpt from `mcpBridge.ts` showing 401 re-auth logic, and from `JsonRpcError.cls` showing the five error code factory methods

## Section 4: Developer Experience — Four Abstract Classes and 12 Lines to a Working Endpoint

- **Purpose**: Show how little code a developer writes to expose Salesforce capabilities to AI agents.
- **Target words**: 400
- **Key points**:
  - Developers extend 4 abstract classes: `McpToolDefinition` (3 methods), `McpResourceDefinition` (1 method), `McpResourceTemplateDefinition` (1 method), `McpPromptDefinition` (1 method)
  - Show the `MinimalMcpEndpoint.cls` — a complete MCP endpoint in 12 lines of Apex
  - Show the `MinimalTool.cls` — an echo tool in 32 lines demonstrating `inputSchema()`, `validate()`, `execute()`
  - Show the `ExampleQueryTool.cls` — a real SOQL tool that searches Account records with `WHERE Name LIKE :('%' + term + '%')`
  - The `McpServer` registration API: `registerTool()`, `registerResource()`, `registerPrompt()` — explicit, no auto-discovery
  - Dynamic capability advertisement: the `initialize` handler only advertises capability types that have registered definitions
  - Two-tier error model: validation failures → `isError: true` tool results; protocol errors → JSON-RPC error responses
- **Claims**: C-010, C-011, C-012, C-013, C-007, C-008
- **Repo links**:
  - https://github.com/damecek/salesforce-mcp-lib/blob/main/force-app/main/mcp/classes/McpToolDefinition.cls
  - https://github.com/damecek/salesforce-mcp-lib/blob/main/force-app/main/mcp/classes/McpServer.cls
  - https://github.com/damecek/salesforce-mcp-lib/blob/main/examples/minimal/force-app/main/default/classes/MinimalMcpEndpoint.cls
  - https://github.com/damecek/salesforce-mcp-lib/blob/main/examples/minimal/force-app/main/default/classes/MinimalTool.cls
  - https://github.com/damecek/salesforce-mcp-lib/blob/main/examples/e2e-http-endpoint/force-app/main/default/classes/ExampleQueryTool.cls
  - https://github.com/damecek/salesforce-mcp-lib/blob/main/examples/e2e-http-endpoint/force-app/main/default/classes/E2eHttpEndpoint.cls
- **Code snippet**: Yes — full `MinimalMcpEndpoint.cls` (12 lines), key excerpt from `MinimalTool.cls` (the three abstract method implementations), and SOQL excerpt from `ExampleQueryTool.cls`

## Section 5: Security — Four Layers You Already Have

- **Purpose**: Explain why the authorization model is a differentiator — AI agents run under the same security as human users, with zero new infrastructure.
- **Target words**: 350
- **Key points**:
  - Four-layer authorization model: API Access (External Client App OAuth scopes), Object/Field Access (Profile + Permission Sets), Record Access (OWD + Sharing Rules), Tool Authorization (custom `validate()` logic)
  - Three of four layers are Salesforce-platform-enforced — no framework code needed
  - OAuth 2.0 client credentials flow: proxy authenticates at startup, caches token, re-authenticates transparently on 401 INVALID_SESSION_ID
  - Secret redaction: `client_secret` replaced with `"****"` at the logging layer before any message reaches stderr
  - Error sanitization: raw Salesforce errors (stack traces, org IDs) never exposed to the MCP client — only generic JSON-RPC error messages cross the trust boundary
  - Comparison to typical AI integration: most frameworks give you a tool executor and leave authorization as an exercise for the reader
- **Claims**: C-014, C-015, C-016, C-017, C-018
- **Repo links**:
  - https://github.com/damecek/salesforce-mcp-lib/blob/main/docs/mcp-authorization-feasibility-report-2026-03-22.md
  - https://github.com/damecek/salesforce-mcp-lib/blob/main/packages/salesforce-mcp-lib/src/index.ts
  - https://github.com/damecek/salesforce-mcp-lib/blob/main/packages/salesforce-mcp-lib/src/mcpBridge.ts
- **Code snippet**: Yes — excerpt from `index.ts` showing the secret redaction wrapper

## Section 6: Getting Started — Clone, Deploy, Connect

- **Purpose**: Give the reader exact steps to go from zero to a working AI-to-Salesforce integration.
- **Target words**: 300
- **Key points**:
  - Step 1: Clone the repo
  - Step 2: Deploy the minimal example with `sf project deploy start --source-dir examples/minimal/force-app --target-org <org>`
  - Step 3: Connect with `npx salesforce-mcp-lib --instance-url ... --client-id ... --client-secret ... --endpoint /services/apexrest/mcp/minimal`
  - Step 4: Test with MCP Inspector: `npx @modelcontextprotocol/inspector npx salesforce-mcp-lib ...`
  - Proxy CLI accepts 4 required flags (`--instance-url`, `--client-id`, `--client-secret`, `--endpoint`) + optional `--log-level`
  - Environment variable alternatives: `SF_INSTANCE_URL`, `SF_CLIENT_ID`, `SF_CLIENT_SECRET`, `SF_ENDPOINT`
  - Two-tier example path: minimal (echo tool, concept validation) → e2e (SOQL queries, org resources, dynamic prompts)
  - NPM package: `salesforce-mcp-lib` v1.0.3, requires Node.js >= 20, zero production dependencies
  - Salesforce package: 2GP unlocked, no namespace — classes referenced directly as `McpServer`
- **Claims**: C-019, C-020, C-021, C-012, C-013
- **Repo links**:
  - https://github.com/damecek/salesforce-mcp-lib/blob/main/examples/minimal/README.md
  - https://github.com/damecek/salesforce-mcp-lib/blob/main/examples/e2e-http-endpoint/README.md
  - https://github.com/damecek/salesforce-mcp-lib/blob/main/packages/salesforce-mcp-lib/package.json
  - https://github.com/damecek/salesforce-mcp-lib/blob/main/sfdx-project.json
- **Code snippet**: Yes — the deploy command and the `npx salesforce-mcp-lib` invocation with full flags

## Section 7: What's Next — And How to Contribute

- **Purpose**: Close with forward momentum — what the project aims to do next and how readers can get involved.
- **Target words**: 200
- **Key points**:
  - The project is open source — contributions, issues, and feedback welcome
  - Current state: production-ready for tools, resources, and prompts; full protocol compliance verified
  - Potential next steps: framework-level tool authorization, streaming support, more examples
  - CTA: star the repo, try the minimal example, open an issue if you build something with it
  - Link to the repo: https://github.com/damecek/salesforce-mcp-lib
- **Claims**: C-001, C-002, C-022
- **Repo links**:
  - https://github.com/damecek/salesforce-mcp-lib
- **Code snippet**: No

---

## Validation

- Sections: [7] (target: 6–8) ✓
- Total target words: [2200] (target: 1500–2500) ✓
- All sections claim-grounded: [YES — every section references 1–6 claims from claims.md] ✓
- All sections have repo links: [YES — every section includes at least 1 full GitHub URL] ✓
- Narrative arc: [problem → context → architecture → DX → security → getting started → closing] ✓
- Code snippet sections: [4] (minimum: 3) ✓ — sections 3, 4, 5, 6
