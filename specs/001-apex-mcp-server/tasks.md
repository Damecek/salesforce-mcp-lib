# Tasks: MCP Server Framework for Salesforce Apex

**Input**: Design documents from `/specs/001-apex-mcp-server/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Included per FR-029 — comprehensive Apex unit tests required (75% minimum for 2GP promotion, 90%+ target). Tests are written within each phase after the classes they test.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1-US6)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create source directory structure, project configuration, and build scaffolding for both Apex and TypeScript codebases.

- [ ] T001 Create SFDX source directory structure: force-app/main/json-rpc/classes/ and force-app/main/mcp/classes/ with required metadata
- [ ] T002 [P] Create TypeScript project skeleton with package.json (name: salesforce-mcp-lib, zero production deps) and tsconfig.json (ES2022, NodeNext, strict) in packages/salesforce-mcp-lib/
- [ ] T003 [P] Create scratch org definition in config/project-scratch-def.json and package version definition in config/package-version-def.json
- [ ] T004 [P] Create core automation scripts: scripts/org-create.sh, scripts/org-delete.sh, scripts/validate.sh

---

## Phase 2: Foundational — JSON-RPC 2.0 Core

**Purpose**: Complete JSON-RPC 2.0 protocol implementation that ALL MCP capabilities depend on. This is the shared runtime for message parsing, handler dispatch, error code generation, and response serialization.

**CRITICAL**: No MCP user story work can begin until this phase is complete.

- [ ] T005 [P] Create JsonRpcIdValue typed ID representation handling string, integer, and null in force-app/main/json-rpc/classes/JsonRpcIdValue.cls
- [ ] T006 [P] Create JsonRpcParamsBase abstract class with virtual validate() and JsonRpcResultBase abstract class in force-app/main/json-rpc/classes/
- [ ] T007 [P] Create JsonRpcError with factory methods for standard codes: parseError (-32700), invalidRequest (-32600), methodNotFound (-32601), invalidParams (-32602), internalError (-32603) in force-app/main/json-rpc/classes/JsonRpcError.cls
- [ ] T008 [P] Create JsonRpcResponse envelope (id, hasResult discriminator, result/error) and JsonRpcExecutionResult container (hasResponse, isBatch, responses list, toJson) in force-app/main/json-rpc/classes/
- [ ] T009 [P] Create JsonRpcInvocationContext with methodName, requestId, rawRequest map, and batchIndex in force-app/main/json-rpc/classes/JsonRpcInvocationContext.cls
- [ ] T010 Create JsonRpcMethodHandler abstract base with method name, param/result types, and abstract invoke(context) in force-app/main/json-rpc/classes/JsonRpcMethodHandler.cls
- [ ] T011 Create JsonRpcModule handler registry (register/getHandler) and JsonRpcModuleBuilder abstract builder (configure/build) in force-app/main/json-rpc/classes/
- [ ] T012 [P] Create JsonRpcExceptionMapper interface (mapException method) and JsonRpcServiceRuntimeOptions (exceptionMapper field) in force-app/main/json-rpc/classes/
- [ ] T013 Create JsonRpcServiceRuntime static dispatcher with JSON parsing, single/batch detection, method routing, notification handling (no-response for missing id), exception mapping, and inner exceptions (ParseFailureException, InvalidRequestException, MethodNotFoundException, InvalidParamsException) in force-app/main/json-rpc/classes/JsonRpcServiceRuntime.cls
- [ ] T014 Create JSON-RPC core unit tests covering: JSON parsing, single request routing, batch request handling, notification detection (no response), all five error codes, unknown method dispatch, malformed JSON, exception mapper integration in force-app/main/json-rpc/classes/

**Checkpoint**: JSON-RPC 2.0 runtime fully operational — message parsing, handler dispatch, error codes, batch support, notification handling all verified by tests.

---

## Phase 3: User Story 1 — Install Package and Implement First MCP Tool (Priority: P1) 🎯 MVP

**Goal**: Developers can install the package, extend McpToolDefinition, register tools in a @RestResource endpoint, and respond correctly to initialize, ping, tools/list, and tools/call via the MCP protocol.

**Independent Test**: Install package in scratch org, create a sample tool class, deploy, and verify tools/list returns the tool metadata and tools/call executes the tool logic via direct HTTP POST.

### MCP Core Infrastructure (shared by all capabilities)

- [ ] T015 [P] [US1] Create McpTextContent with type field (always "text") and text field, including String constructor in force-app/main/mcp/classes/McpTextContent.cls
- [ ] T016 [P] [US1] Create McpExceptions container class with inner DuplicateRegistrationException, and McpInvalidParamsException extending Exception in force-app/main/mcp/classes/
- [ ] T017 [P] [US1] Create MCP initialization types: McpInitializeParams (protocolVersion, capabilities, clientInfo), McpInitializeCapabilities (roots, sampling entries), McpInitializeCapabilityEntry, McpInitializeClientInfo (name, version), McpInitializeServerInfo (name, version) in force-app/main/mcp/classes/
- [ ] T018 [P] [US1] Create McpInitializeResult (protocolVersion, capabilities map, serverInfo, optional instructions) extending JsonRpcResultBase in force-app/main/mcp/classes/McpInitializeResult.cls
- [ ] T019 [US1] Create McpHttpTransport wrapping RestRequest/RestResponse with getRequestBody() and setResponseBody(String) methods in force-app/main/mcp/classes/McpHttpTransport.cls
- [ ] T020 [US1] Create McpNamedArgumentsParams extending JsonRpcParamsBase with loadFromRaw(Map) method for extracting dynamic arguments from raw request params in force-app/main/mcp/classes/McpNamedArgumentsParams.cls

### Tool-Specific Classes

- [ ] T021 [P] [US1] Create McpToolAnnotations (readOnlyHint, destructiveHint, idempotentHint, openWorldHint) and McpToolAnnotationsWire for JSON serialization in force-app/main/mcp/classes/
- [ ] T022 [US1] Create McpToolDefinition abstract base with name, description, annotations fields and abstract inputSchema(), validate(Map), execute(Map) methods in force-app/main/mcp/classes/McpToolDefinition.cls
- [ ] T023 [US1] Create McpToolResult extending JsonRpcResultBase with content (List of McpTextContent) and isError flag in force-app/main/mcp/classes/McpToolResult.cls

### MCP Handlers and Server

- [ ] T024 [US1] Create McpJsonRpcExceptionMapper implementing JsonRpcExceptionMapper: map McpInvalidParamsException to -32602, general Exception to -32603 in force-app/main/mcp/classes/McpJsonRpcExceptionMapper.cls
- [ ] T025 [US1] Create McpInitializeHandler extending JsonRpcMethodHandler: return protocolVersion "2025-11-25", capabilities based on registered tools/resources/prompts, serverInfo with name "SalesforceMcpServer" and version "1.1.0" in force-app/main/mcp/classes/McpInitializeHandler.cls
- [ ] T026 [P] [US1] Create McpPingHandler extending JsonRpcMethodHandler returning empty result object in force-app/main/mcp/classes/McpPingHandler.cls
- [ ] T027 [P] [US1] Create McpNotificationHandler for notifications/initialized that returns no-response result (hasResponse=false) in force-app/main/mcp/classes/McpNotificationHandler.cls
- [ ] T028 [US1] Create McpToolsListHandler: iterate registered tools, build response with name, description, inputSchema for each tool in force-app/main/mcp/classes/McpToolsListHandler.cls
- [ ] T029 [US1] Create McpToolsCallHandler: extract tool name from params, look up tool, call validate() then execute(), catch McpInvalidParamsException and general exceptions to return isError:true results, return -32602 for unknown tool in force-app/main/mcp/classes/McpToolsCallHandler.cls
- [ ] T030 [US1] Create McpJsonRpcModuleBuilder extending JsonRpcModuleBuilder: register handlers for initialize, notifications/initialized, ping, tools/list, tools/call; accept registered capability lists from McpServer in force-app/main/mcp/classes/McpJsonRpcModuleBuilder.cls
- [ ] T031 [US1] Create McpServer with registerTool (duplicate name check), handleRequest (build module via McpJsonRpcModuleBuilder, call JsonRpcServiceRuntime.execute, write response via McpHttpTransport) in force-app/main/mcp/classes/McpServer.cls

### Tests for User Story 1

- [ ] T032 [US1] Create Apex unit tests for MCP tools flow: tool registration, duplicate tool rejection, tools/list wire format, tools/call with valid args, tools/call with validation failure (isError:true), tools/call for unknown tool (-32602), initialize response with capabilities, ping response, exception mapper behavior in force-app/main/mcp/classes/

**Checkpoint**: Apex MCP server handles initialize, notifications/initialized, ping, tools/list, and tools/call. A developer can create a tool class, register it, and test via direct HTTP POST to a @RestResource endpoint.

---

## Phase 4: User Story 2 — Connect AI Agent via MCP (Priority: P2)

**Goal**: A TypeScript stdio proxy bridges MCP clients to the Salesforce Apex endpoint via OAuth 2.0 client credentials, handling session management, request forwarding, and error translation.

**Independent Test**: Start the proxy, connect MCP Inspector, complete initialization handshake, call a tool, and verify end-to-end response through the full pipeline.

### Implementation for User Story 2

- [ ] T033 [P] [US2] Create types.ts with BridgeConfig, OAuthTokenResponse, McpSession (sessionId, protocolVersion, serverCapabilities, state), and JsonRpcMessage interfaces in packages/salesforce-mcp-lib/src/types.ts
- [ ] T034 [P] [US2] Create errors.ts with SalesforceAuthError (auth failures) and RemoteMcpError (non-JSON/HTTP error responses from Salesforce) classes in packages/salesforce-mcp-lib/src/errors.ts
- [ ] T035 [US2] Create config.ts: parse --instance-url, --client-id, --client-secret, --endpoint (required) and --log-level (optional, default info) from CLI args with env variable fallback (SF_INSTANCE_URL, SF_CLIENT_ID, SF_CLIENT_SECRET, SF_ENDPOINT, SF_LOG_LEVEL) in packages/salesforce-mcp-lib/src/config.ts
- [ ] T036 [US2] Create oauth.ts: POST to /services/oauth2/token with grant_type=client_credentials, cache access_token and instance_url from response, export authenticate() and getToken() functions in packages/salesforce-mcp-lib/src/oauth.ts
- [ ] T037 [US2] Create mcpBridge.ts: forward JSON-RPC messages as HTTP POST to instance_url+endpoint with Bearer token, handle HTTP 200 (forward response), HTTP 401 (re-auth + retry once), HTTP 500 (parse APEX_ERROR, translate to -32603), network errors (translate to -32603, no retry) in packages/salesforce-mcp-lib/src/mcpBridge.ts
- [ ] T038 [US2] Create stdio.ts: readline interface on stdin for newline-delimited JSON-RPC input, write responses to stdout with newline framing, configurable stderr logger (debug/info/warn/error levels) in packages/salesforce-mcp-lib/src/stdio.ts
- [ ] T039 [US2] Create index.ts CLI entry point: parse config → validate required params (exit 1 if missing) → authenticate (exit 1 on failure) → start stdio listener → on each message call bridge → write response; configure as package bin entry in packages/salesforce-mcp-lib/src/index.ts

**Checkpoint**: Full end-to-end MCP pipeline working — MCP Inspector can connect via stdio proxy, complete initialization handshake, discover tools, and execute tool calls through to Salesforce and back.

---

## Phase 5: User Story 3 — Implement MCP Resources (Priority: P3)

**Goal**: Developers can implement read-only MCP Resources to expose Salesforce data to AI agents, discoverable via resources/list and readable via resources/read. Resource templates provide URI-based dynamic resource access.

**Independent Test**: Create a resource class, register it, verify resources/list returns metadata and resources/read returns text or binary content.

### Implementation for User Story 3

- [ ] T040 [P] [US3] Create McpResourceContentItem with uri, mimeType, text (mutually exclusive with blob), and blob (base64, mutually exclusive with text) in force-app/main/mcp/classes/McpResourceContentItem.cls
- [ ] T041 [P] [US3] Create McpResourceDefinition abstract base (uri, name, description, mimeType, abstract read()) and McpResourceResult extending JsonRpcResultBase (contents list) in force-app/main/mcp/classes/
- [ ] T042 [P] [US3] Create McpResourceTemplateDefinition abstract base (uriTemplate, name, description, mimeType, abstract read(Map templateArguments)) in force-app/main/mcp/classes/McpResourceTemplateDefinition.cls
- [ ] T043 [US3] Create McpResourcesListHandler (return registered resources with uri, name, description, mimeType) and McpResourcesReadHandler (look up resource by URI, call read(), return contents; -32602 for unknown URI) in force-app/main/mcp/classes/
- [ ] T044 [US3] Create McpResourcesTemplatesListHandler (return registered templates with uriTemplate, name, description, mimeType) and McpResourcesTemplatesCallHandler (look up template, call read with args) in force-app/main/mcp/classes/
- [ ] T045 [US3] Add registerResource (duplicate URI check) and registerResourceTemplate (duplicate uriTemplate check) to McpServer; update McpJsonRpcModuleBuilder to register resources/list, resources/read, resources/templates/list, resources/templates/call handlers; update initialize capabilities to include resources when registered in force-app/main/mcp/classes/
- [ ] T046 [US3] Create Apex unit tests for MCP resources: resource registration, duplicate URI rejection, resources/list wire format, resources/read with text content, resources/read with binary/blob content, unknown URI error (-32602), template registration and listing, initialize capabilities includes resources when registered in force-app/main/mcp/classes/

**Checkpoint**: Resources and resource templates fully functional. resources/list, resources/read, resources/templates/list, resources/templates/call all working and tested.

---

## Phase 6: User Story 4 — Implement MCP Prompts (Priority: P4)

**Goal**: Developers can implement MCP Prompts as reusable prompt templates, discoverable via prompts/list and retrievable via prompts/get with argument substitution.

**Independent Test**: Create a prompt class with required/optional arguments, register it, verify prompts/list returns metadata with argument definitions and prompts/get returns correctly formatted messages.

### Implementation for User Story 4

- [ ] T047 [P] [US4] Create McpPromptArgumentDefinition with name, description, and required flag; include constructor(name, description, required) in force-app/main/mcp/classes/McpPromptArgumentDefinition.cls
- [ ] T048 [P] [US4] Create McpPromptMessage with role (user/assistant) and content (McpTextContent); include constructor(role, content) in force-app/main/mcp/classes/McpPromptMessage.cls
- [ ] T049 [US4] Create McpPromptDefinition abstract base (name, description, arguments list, abstract get(Map arguments)) and McpPromptResult extending JsonRpcResultBase (description, messages list) in force-app/main/mcp/classes/
- [ ] T050 [US4] Create McpPromptsListHandler (return registered prompts with name, description, arguments) and McpPromptsGetHandler (look up prompt by name, call get() with arguments map, return messages; -32602 for unknown prompt) in force-app/main/mcp/classes/
- [ ] T051 [US4] Add registerPrompt (duplicate name check) to McpServer; update McpJsonRpcModuleBuilder to register prompts/list and prompts/get handlers; update initialize capabilities to include prompts when registered in force-app/main/mcp/classes/
- [ ] T052 [US4] Create Apex unit tests for MCP prompts: prompt registration, duplicate name rejection, prompts/list wire format with argument definitions, prompts/get with valid args, prompts/get for unknown prompt (-32602), initialize capabilities includes prompts when registered in force-app/main/mcp/classes/

**Checkpoint**: Prompts fully functional. prompts/list and prompts/get working with argument validation and tested.

---

## Phase 7: User Story 5 — Test with MCP Inspector & Examples (Priority: P5)

**Goal**: Developer can interactively test and debug their MCP server using MCP Inspector. Reference implementations demonstrate all three capability types (tool, resource, prompt) for developers to learn from.

**Independent Test**: Run Inspector against proxy, verify initialize → tools/list → tools/call → resources/list → resources/read → prompts/list → prompts/get workflow completes without protocol errors.

### Implementation for User Story 5

- [ ] T053 [P] [US5] Create minimal example: single tool class and @RestResource endpoint in examples/minimal/ with deployment instructions
- [ ] T054 [P] [US5] Create full endpoint example with tool, resource, and prompt classes plus @RestResource endpoint in examples/e2e-http-endpoint/ demonstrating all three capability types
- [ ] T055 [US5] Create development harness Apex classes (DevMcpHarness endpoint, sample tool/resource/prompt implementations) for scratch org testing in dev/mcp-harness/force-app/
- [ ] T056 [US5] Create MCP Inspector launch configuration and connection script in dev/mcp-harness/inspector/
- [ ] T057 [US5] Create harness automation scripts: scripts/harness-deploy.sh (deploy harness to scratch org), scripts/harness-remove.sh (clean up), scripts/harness-test.sh (run Inspector against harness) in scripts/

**Checkpoint**: MCP Inspector connects via proxy, completes handshake, discovers all capabilities, and successfully executes sample tools, reads resources, and gets prompts.

---

## Phase 8: User Story 6 — Secure MCP Access with Authentication (Priority: P6)

**Goal**: Only authenticated AI agents with valid OAuth tokens can access the MCP server. Authentication failures produce clear error messages. Token expiration triggers transparent re-authentication.

**Independent Test**: Attempt connection without credentials (expect startup failure), with valid credentials (expect success), simulate expired token (expect transparent re-auth).

### Implementation for User Story 6

- [ ] T058 [US6] Harden proxy startup authentication: validate token immediately after OAuth exchange, emit clear error message to stderr on failure, exit code 1 on auth failure, redact secrets in all log output in packages/salesforce-mcp-lib/src/index.ts
- [ ] T059 [US6] Harden proxy 401 re-authentication: on INVALID_SESSION_ID retry once with fresh token, on persistent auth failure return JSON-RPC -32603 with descriptive message (not raw Salesforce error), log re-auth events at warn level in packages/salesforce-mcp-lib/src/mcpBridge.ts
- [ ] T060 [US6] Validate all US6 acceptance scenarios end-to-end: unauthenticated client rejection, valid token request processing, expired token transparent re-authentication

**Checkpoint**: Auth hardened — invalid credentials fail fast at startup with clear errors, expired tokens trigger transparent re-authentication, all auth scenarios validated.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Package release automation, comprehensive test coverage verification, documentation, and final validation.

- [ ] T061 [P] Create package release automation scripts: scripts/release-create.sh (sf package version create with code coverage), scripts/release-promote.sh (sf package version promote) in scripts/
- [ ] T062 [P] Create remaining automation scripts: scripts/org-push.sh (source push), scripts/org-test.sh (run Apex tests), scripts/task-prepare.sh (feature branch setup) in scripts/
- [ ] T063 Verify Apex test coverage exceeds 90% across all packaged classes in force-app/; add targeted tests for any coverage gaps identified
- [ ] T064 [P] Create audit documentation: docs/mcp-wire-contract-audit-2025-11-25.md (protocol compliance audit) and docs/mcp-authorization-feasibility-report-2026-03-22.md in docs/
- [ ] T065 Run full validation suite: Apex unit tests pass, TypeScript compiles cleanly, MCP Inspector end-to-end succeeds, quickstart.md walkthrough verified

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 completion — BLOCKS all user stories
- **US1 Tools (Phase 3)**: Depends on Phase 2 — builds MCP core infrastructure + tools capability
- **US2 Proxy (Phase 4)**: Depends on Phase 3 — proxy needs a working Apex MCP endpoint to forward to
- **US3 Resources (Phase 5)**: Depends on Phase 3 — extends McpServer with resource capability
- **US4 Prompts (Phase 6)**: Depends on Phase 3 — extends McpServer with prompt capability
- **US5 Testing (Phase 7)**: Depends on Phases 3 + 4 (minimum); ideally 5 + 6 for full capability testing
- **US6 Auth (Phase 8)**: Depends on Phase 4 — hardens proxy authentication behavior
- **Polish (Phase 9)**: Depends on all desired user stories being complete

### User Story Independence

- **US1 (P1)**: Depends only on Foundational — no other story dependencies
- **US2 (P2)**: Depends on US1 — needs working Apex endpoint
- **US3 (P3)**: Depends on US1 only — can run in **PARALLEL** with US2
- **US4 (P4)**: Depends on US1 only — can run in **PARALLEL** with US2 and US3
- **US5 (P5)**: Depends on US1 + US2 minimum
- **US6 (P6)**: Depends on US2

### Parallel Opportunities

**Within Phase 2 (Foundational)**:
T005, T006, T007, T008, T009, T012 can all run in parallel (independent type definitions with no cross-dependencies)

**Within Phase 3 (US1)**:
T015, T016, T017, T018, T021 can run in parallel (independent DTO/exception classes)
T026, T027 can run in parallel (independent simple handlers)

**Within Phase 4 (US2)**:
T033, T034 can run in parallel (types.ts and errors.ts are independent)

**Cross-Phase Parallelism** (once US1 is complete):
- Stream A: TypeScript proxy (US2, Phase 4)
- Stream B: Apex resources (US3, Phase 5)
- Stream C: Apex prompts (US4, Phase 6)

All three streams can execute simultaneously since they modify different files with no cross-dependencies.

---

## Parallel Execution Examples

### Phase 2 Parallel Batch
```
T005: JsonRpcIdValue.cls
T006: JsonRpcParamsBase.cls + JsonRpcResultBase.cls
T007: JsonRpcError.cls
T008: JsonRpcResponse.cls + JsonRpcExecutionResult.cls
T009: JsonRpcInvocationContext.cls
T012: JsonRpcExceptionMapper.cls + JsonRpcServiceRuntimeOptions.cls
```

### Phase 3 Parallel Batch (after Phase 2)
```
T015: McpTextContent.cls
T016: McpExceptions.cls + McpInvalidParamsException.cls
T017: McpInitialize*.cls (5 classes)
T018: McpInitializeResult.cls
T021: McpToolAnnotations.cls + McpToolAnnotationsWire.cls
```

### Post-US1 Cross-Phase Parallelism
```
Stream A (US2): T033→T034→T035→T036→T037→T038→T039
Stream B (US3): T040→T041→T042→T043→T044→T045→T046
Stream C (US4): T047→T048→T049→T050→T051→T052
```

---

## Implementation Strategy

### MVP First (US1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (JSON-RPC 2.0 core — ~13 Apex classes)
3. Complete Phase 3: US1 (MCP core + tools — ~18 Apex classes)
4. **STOP AND VALIDATE**: Deploy to scratch org, test via direct HTTP POST to @RestResource

### End-to-End Validation (US1 + US2)

5. Complete Phase 4: US2 (TypeScript proxy — 6 modules)
6. **STOP AND VALIDATE**: Test with MCP Inspector through stdio proxy

### Full Capability (US3 + US4)

7. Complete Phases 5 & 6 in parallel: US3 (Resources) + US4 (Prompts)
8. **STOP AND VALIDATE**: All three capabilities working via Inspector

### Release Ready

9. Complete Phase 7: US5 (Examples + Inspector harness)
10. Complete Phase 8: US6 (Auth hardening)
11. Complete Phase 9: Polish (coverage ≥ 90%, scripts, docs)
12. Create package version: `sf package version create --package SalesforceMcpLib --code-coverage`

---

## Notes

- Each Apex `.cls` file must have a corresponding `.cls-meta.xml` (apiVersion: 65.0, status: Active)
- JSON-RPC core (`force-app/main/json-rpc/`) has NO dependency on MCP layer
- MCP layer (`force-app/main/mcp/`) depends on JSON-RPC core
- TypeScript proxy uses ZERO production npm dependencies — Node.js built-ins only (readline, https, crypto)
- Existing 2GP package: SalesforceMcpLib (0HodL0000002PQXSA2), version 1.1.0.NEXT
- All handler classes extend JsonRpcMethodHandler from the JSON-RPC core
- McpServer passes registered capability lists to McpJsonRpcModuleBuilder so handlers can access them
- `JSON.serialize(obj, true)` suppresses null fields — use for all wire output
- Notifications (no `id` field) must return JsonRpcExecutionResult with `hasResponse = false`
