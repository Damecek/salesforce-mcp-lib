# Implementation Plan: MCP Server Framework for Salesforce Apex

**Branch**: `001-apex-mcp-server` | **Date**: 2026-03-30 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-apex-mcp-server/spec.md`

## Summary

Implement a complete MCP 2025-11-25 server framework in Salesforce Apex, distributed as a second-generation unlocked package (2GP, no namespace), paired with a TypeScript/Node.js stdio proxy that bridges local AI agents to subscriber-defined Salesforce REST endpoints via OAuth 2.0 client credentials. The Apex framework provides extensible base classes for tools, resources, and prompts; subscriber developers implement these, register them programmatically in their own `@RestResource` endpoints, and expose them to any MCP-compliant AI agent. The proxy owns all session state; the Apex layer is fully stateless per request.

## Technical Context

**Language/Version**: Apex (Salesforce API 65.0) + TypeScript (ES2022, Node.js >= 20)
**Primary Dependencies**: Zero external dependencies. Apex uses platform-native APIs only. TypeScript uses Node.js built-in modules only (no production npm dependencies). JSON-RPC 2.0 core is implemented in-repo, not imported.
**Storage**: Salesforce platform (SOQL/SOSL/DML) — accessed by subscriber tool/resource implementations, not by the framework itself. The framework stores no persistent data.
**Testing**: Salesforce native Apex test framework + Node.js built-in test runner with `tsx`. End-to-end via MCP Inspector (`npx @modelcontextprotocol/inspector`).
**Target Platform**: Salesforce orgs (Apex runtime, API 65.0) for the server; local Node.js runtime for the stdio proxy.
**Project Type**: Library (Apex 2GP package) + CLI bridge (npm package `salesforce-mcp-lib`).
**Performance Goals**: < 5s round-trip for tool invocations (excluding Salesforce API latency); 10+ concurrent MCP sessions without cross-contamination (SC-003, SC-004).
**Constraints**: Apex governor limits (CPU time, heap size, SOQL query count) per transaction; stateless Apex — no cross-request session state; 2GP packaging requires >= 75% Apex test coverage (target 90%+); zero production npm dependencies for the proxy.
**Scale/Scope**: ~77 Apex classes (19 JSON-RPC core + 58 MCP layer) in a single 2GP package; ~6 TypeScript modules in one npm package; 19 bash automation scripts; 2 example implementations.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle I: AI-Agent-First Development

| Requirement | Status | Evidence |
|---|---|---|
| Descriptive, consistent file/directory naming | PASS | Apex classes follow `Mcp*` / `JsonRpc*` prefix conventions; TS modules are single-purpose with clear names (`oauth.ts`, `mcpBridge.ts`, `stdio.ts`). |
| Public interfaces include documentation comments | PASS | All public Apex classes require ApexDoc; TS interfaces defined in `types.ts` with JSDoc. |
| Explicit, linear control flow | PASS | Stateless Apex per-request design avoids hidden async flows; proxy uses straightforward stdin→HTTP→stdout pipeline. |
| Meaningful commit messages | PASS | Enforced by constitution governance; commit style follows "why not what" convention. |

### Principle II: Agent-Consumable APIs

| Requirement | Status | Evidence |
|---|---|---|
| Strict JSON-RPC 2.0 / MCP 2025-11-25 compliance | PASS | Wire-contract audit performed (`docs/mcp-wire-contract-audit-2025-11-25.md`). In-repo JSON-RPC 2.0 implementation with full error codes. |
| Structured, typed error codes | PASS | `JsonRpcError` factory methods for -32700, -32600, -32601, -32602, -32603; `McpExceptions` and `McpInvalidParamsException` for MCP-layer errors; TS-side `SalesforceAuthError`, `RemoteMcpError`. |
| Complete JSON Schema descriptors for tools/resources/prompts | PASS | Tool input schemas defined via `Map<String, Object>` mirroring JSON Schema (FR-006); listed items include name, description, and schema in wire responses. |
| Standards-compliant message framing (stdio) | PASS | Proxy implements newline-delimited JSON-RPC over stdio. |

### Principle III: Maintainability & Reusability

| Requirement | Status | Evidence |
|---|---|---|
| Standalone 2GP, no subscriber-org assumptions | PASS | Package is namespace-free unlocked 2GP; no Custom Metadata Types or Custom Settings (FR-026); subscriber creates their own `@RestResource`. |
| Zero production npm dependencies | PASS | TS proxy uses only Node.js built-ins (`node:http`, `node:readline`, `node:crypto`, etc.). |
| Single-responsibility modules | PASS | JSON-RPC core separated from MCP layer; TS modules split by concern (config, oauth, bridge, stdio, errors, types). |
| Shared types in dedicated locations | PASS | Apex DTOs in per-class files under `json-rpc/classes` and `mcp/classes`; TS types in `types.ts`. |

### Principle IV: Strong Typing

| Requirement | Status | Evidence |
|---|---|---|
| Typed JsonRpcParamsBase subclasses | PASS | `McpInitializeParams`, `McpToolCallRpcParams`, `McpResourcesReadRpcParams`, `McpPromptGetRpcParams` all define typed properties. |
| TS interfaces in types.ts, no `any` | PASS | All config, message, and response shapes in `types.ts`; `any` prohibited in public API signatures. |
| Complete JSON Schema for tool inputs | PASS | Framework mandates schema definition via `inputSchema()` method on tool interface. |
| Specific error classes | PASS | Apex: `McpInvalidParamsException`, `McpExceptions`; TS: `SalesforceAuthError`, `RemoteMcpError`. |
| `Map<String, Object>` prohibition for public APIs | **TENSION** | See Complexity Tracking. Tool arguments are inherently dynamic — the framework cannot know subscriber-defined schemas at compile time. The `Map<String, Object>` usage is confined to the tool/resource/prompt developer boundary, not the framework's own JSON-RPC params. |

**Gate Result**: PASS (with one documented tension — see Complexity Tracking)

### Post-Phase 1 Re-Check

| Principle | Status | Post-Design Evidence |
|---|---|---|
| I. AI-Agent-First Development | PASS | Data model uses descriptive class names (`McpToolDefinition`, `McpResourceResult`). Contracts include full documentation and code examples. Quickstart follows linear step-by-step flow. All artifacts structured for agent comprehension. |
| II. Agent-Consumable APIs | PASS | Wire contracts document exact JSON-RPC messages with request/response examples. Two-tier error model (protocol vs tool errors) fully documented. Complete JSON Schema examples in contracts and quickstart. Proxy CLI contract specifies all parameters and error translation rules. |
| III. Maintainability & Reusability | PASS | Data model cleanly separates JSON-RPC core (19 classes) from MCP layer (58 classes). TypeScript entities organized by concern (config, oauth, bridge, stdio, errors, types). No subscriber-org assumptions in framework design. Zero production npm dependencies confirmed in proxy contract. |
| IV. Strong Typing | PASS (with documented exception) | All JSON-RPC params use typed classes (`McpInitializeParams`, `McpToolCallRpcParams`, etc.). TypeScript interfaces defined for `BridgeConfig`, `OAuthTokenResponse`, `McpSession`. Error classes are specific (`McpInvalidParamsException`, `SalesforceAuthError`, `RemoteMcpError`). `Map<String, Object>` tension for tool arguments acknowledged and tracked in Complexity Tracking — confined to the subscriber developer boundary only. |

**Post-Design Gate Result**: PASS — no new violations introduced by Phase 1 design artifacts.

## Project Structure

### Documentation (this feature)

```text
specs/001-apex-mcp-server/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
force-app/                              # Salesforce 2GP package source
├── main/
│   ├── json-rpc/                      # JSON-RPC 2.0 core (in-repo)
│   │   └── classes/                   # ~19 classes: runtime, handlers, params, errors
│   └── mcp/                           # MCP 2025-11-25 layer
│       └── classes/                   # ~58 classes: server, tools, resources, prompts, transport

packages/salesforce-mcp-lib/            # TypeScript stdio proxy (npm package)
├── src/                               # 6 modules: index, types, config, oauth, mcpBridge, stdio, errors
├── tests/                             # Unit + E2E tests
├── dist/                              # Compiled JS output
├── package.json                       # npm metadata (salesforce-mcp-lib@1.0.2)
└── tsconfig.json                      # ES2022, NodeNext, strict

scripts/                                # 19 bash automation scripts
├── org-*.sh                           # Scratch org lifecycle
├── harness-*.sh                       # Development harness operations
├── release-*.sh                       # 2GP package release pipeline
├── validate.sh                        # Full validation suite
└── task-prepare*.sh                   # Feature work preparation

examples/                               # Reference implementations
├── minimal/                           # Bare-minimum tool example
└── e2e-http-endpoint/                 # Full endpoint pattern

dev/mcp-harness/                        # Development testing harness
├── force-app/                         # Test Apex classes (DevMcpHarness*)
└── inspector/                         # MCP Inspector configuration

config/                                 # Package configuration
├── package-version-def.json           # 2GP version definition
└── project-scratch-def.json           # Scratch org shape

docs/                                   # Design and audit documentation
├── mcp-wire-contract-audit-2025-11-25.md
└── mcp-authorization-feasibility-report-2026-03-22.md
```

**Structure Decision**: Dual-platform monorepo. Apex source under `force-app/` (Salesforce DX convention) with JSON-RPC and MCP as separate source directories within one 2GP package. TypeScript proxy under `packages/salesforce-mcp-lib/` as an npm workspace package. Automation scripts at `scripts/`. This structure is already established and proven through multiple package releases (1.0.0 through 1.1.0).

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| `Map<String, Object>` used for tool arguments at the developer interface boundary (Principle IV) | Tool input schemas are developer-defined and arbitrary — the framework cannot know the subscriber's schema at compile time. Arguments arrive as deserialized JSON and must be passed as a generic map. | Typed params would require the framework to generate Apex classes per tool at compile time, which Apex does not support. The alternative of requiring developers to write their own deserialization was rejected because it shifts too much protocol knowledge to the subscriber. The framework's own internal APIs (JSON-RPC params, MCP params) use fully typed classes; only the developer-facing tool/resource/prompt boundary uses `Map<String, Object>`. |
