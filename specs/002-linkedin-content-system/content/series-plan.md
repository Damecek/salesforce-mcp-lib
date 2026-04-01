# Series Plan: Salesforce MCP Library

**Generated**: 2026-04-01
**Source**: Repository analysis of salesforce-mcp-lib

## Topic 1: Your Salesforce Org Already Speaks AI — It Just Needs a Protocol

**Arc position**: Awareness
**Core message**: The Model Context Protocol (MCP) is becoming the standard way AI agents discover and use external capabilities. Salesforce MCP Library is the first production-ready MCP server framework that runs natively in Apex, letting AI agents interact with your Salesforce data and logic through a standard protocol — without middleware, without ETL, without moving data out of the org.
**CTA angle**: Star the repo and explore the minimal example to see how few lines it takes to expose your first Salesforce tool to an AI agent.
**Contrarian hook**: Everyone's racing to build AI integrations by pulling enterprise data *out* of Salesforce and feeding it to models. But the org already has the data, the permissions, and the business logic — what it was missing was a protocol. Now it has one.
**Repo artifacts**:
- `force-app/main/mcp/classes/McpServer.cls`
- `force-app/main/mcp/classes/McpToolDefinition.cls`
- `examples/minimal/force-app/main/default/classes/MinimalMcpEndpoint.cls`
- `specs/001-apex-mcp-server/spec.md`

## Topic 2: The Hidden Cost of "Just Build an API" for AI Integration

**Arc position**: Problem
**Core message**: Teams currently connect AI agents to Salesforce through custom REST endpoints, middleware layers, or data replication pipelines. Each approach creates the same problems: scattered credentials, brittle integrations, no standard capability discovery, and data leaving the security perimeter. MCP solves this by providing a single protocol where agents discover what's available, validate inputs against schemas, and execute within the org's existing security model.
**CTA angle**: Audit your current Salesforce-to-AI integration stack and count the credential stores, custom endpoints, and data-copy jobs — then consider what a single-protocol approach would eliminate.
**Contrarian hook**: "Just build a REST API" is the most expensive sentence in enterprise AI integration. Every custom endpoint is a maintenance liability, a security surface, and a capability that no AI agent can discover on its own. The real cost isn't building v1 — it's maintaining v47 when the org has 200 tools and three teams adding more.
**Repo artifacts**:
- `docs/mcp-authorization-feasibility-report-2026-03-22.md`
- `docs/mcp-wire-contract-audit-2025-11-25.md`
- `specs/001-apex-mcp-server/research.md`
- `force-app/main/mcp/classes/McpInitializeHandler.cls`

## Topic 3: Zero Dependencies, Two Layers, Full Protocol — Inside the Architecture

**Arc position**: Technical
**Core message**: The library implements a two-layer architecture: a stateless Apex server (JSON-RPC 2.0 + MCP 2025-11-25, 77 classes, zero external dependencies) that rebuilds per request inside Salesforce governor limits, paired with a stateful TypeScript stdio proxy (zero npm dependencies, Node.js built-ins only) that handles OAuth, token lifecycle, and MCP transport. This design works *with* Salesforce platform constraints rather than fighting them — the proxy owns session state so the Apex endpoint stays stateless, and the in-repo JSON-RPC implementation eliminates supply-chain risk entirely.
**CTA angle**: Read the wire-contract audit to see how every MCP method maps to the implementation, then trace a request from stdio through the proxy to Apex and back.
**Contrarian hook**: The best protocol implementation is the one with zero dependencies. Not "minimal" dependencies — zero. When your MCP server has no node_modules and no external Apex libraries, there's nothing to audit, nothing to update, and nothing that can break when a transitive dependency pushes a bad release on a Friday afternoon.
**Repo artifacts**:
- `force-app/main/json-rpc/classes/JsonRpcServiceRuntime.cls`
- `force-app/main/mcp/classes/McpJsonRpcModuleBuilder.cls`
- `packages/salesforce-mcp-lib/src/mcpBridge.ts`
- `packages/salesforce-mcp-lib/src/stdio.ts`
- `packages/salesforce-mcp-lib/src/oauth.ts`
- `docs/mcp-wire-contract-audit-2025-11-25.md`
- `specs/001-apex-mcp-server/plan.md`

## Topic 4: Four Layers of Security You Didn't Have to Build

**Arc position**: Impact
**Core message**: Most AI integration frameworks punt on authorization — they give you a tool executor and wish you luck. Salesforce MCP Library inherits a four-layer security model for free: Connected App OAuth scopes control API access, Profile and Permission Sets enforce object/field visibility, OWD and Sharing Rules govern record access, and developer-written `validate()` methods add tool-specific authorization. The result: AI agents operate under the same security policies as your users, with zero additional infrastructure. Meanwhile, the developer experience stays simple — extend 4 abstract classes, implement 2–3 methods each, and the framework handles protocol compliance, error translation, and capability advertisement.
**CTA angle**: Map your org's existing permission model to the four authorization layers and identify which Salesforce tools you could safely expose to AI agents today — without building any new security infrastructure.
**Contrarian hook**: The most secure AI integration is the one where you build *nothing* new for security. Every custom auth layer is a liability. When your AI agent runs as a Salesforce user with profiles, permission sets, and sharing rules already in place, you get enterprise-grade authorization on day one — not after a six-month security review.
**Repo artifacts**:
- `docs/mcp-authorization-feasibility-report-2026-03-22.md`
- `force-app/main/mcp/classes/McpToolDefinition.cls`
- `force-app/main/mcp/classes/McpResourceDefinition.cls`
- `force-app/main/mcp/classes/McpPromptDefinition.cls`
- `force-app/main/mcp/classes/McpExceptions.cls`
- `packages/salesforce-mcp-lib/src/errors.ts`

## Topic 5: From Zero to AI-Enabled Org in 30 Lines of Apex

**Arc position**: Adoption
**Core message**: Getting started requires two classes (~30 lines of Apex total): one `@RestResource` endpoint that instantiates `McpServer` and registers capabilities, and one tool/resource/prompt definition. Deploy with a single `sf project deploy start` command, connect with `npx salesforce-mcp-lib`, and your org is speaking MCP. The library ships with a two-tier example path — a minimal echo tool for concept validation and a full e2e example with SOQL queries, org resources, and dynamic prompts — so teams can go from "what is this?" to "this is in our sandbox" in an afternoon.
**CTA angle**: Clone the repo, deploy the minimal example to a scratch org, and connect it to Claude Desktop or the MCP Inspector — you'll have a working AI-to-Salesforce integration before your next meeting.
**Contrarian hook**: Most enterprise AI "getting started" guides should really be called "getting started in two weeks after procurement approves the middleware license." This one is a single deploy command and 30 lines of Apex. If your team can't evaluate it in an afternoon, the framework has failed — not your team.
**Repo artifacts**:
- `examples/minimal/force-app/main/default/classes/MinimalMcpEndpoint.cls`
- `examples/minimal/force-app/main/default/classes/MinimalTool.cls`
- `examples/minimal/README.md`
- `examples/e2e-http-endpoint/force-app/main/default/classes/E2eHttpEndpoint.cls`
- `examples/e2e-http-endpoint/force-app/main/default/classes/ExampleQueryTool.cls`
- `examples/e2e-http-endpoint/README.md`
- `packages/salesforce-mcp-lib/package.json`

---

## Validation

- Topics: [5/5]
- Overlap check: [PASS — no pair exceeds 20% overlap. Topic 1 introduces the concept; Topic 2 focuses on the business problem with existing approaches; Topic 3 dives into architecture and implementation; Topic 4 covers security model and developer experience impact; Topic 5 is purely practical adoption. Each occupies distinct conceptual territory.]
- Repo grounding: [PASS — all core messages reference specific repo artifacts. 28 total artifact references across 5 topics, covering all 7 scanned repository areas.]
- Narrative arc: [awareness → problem → technical → impact → adoption]
