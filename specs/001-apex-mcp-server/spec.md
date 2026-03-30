# Feature Specification: MCP Server Framework for Salesforce Apex

**Feature Branch**: `001-apex-mcp-server`
**Created**: 2026-03-28
**Status**: Draft
**Input**: User description: "Implement MCP in Apex language with local TS HTTP-to-stdio proxy. Second generation Salesforce packages. Latest MCP specification (2025-11-25). With broad testing in Apex, and outside invocation using MCP Inspector. Customers install the 2GP package, implement desired tools/resources/prompts using the package framework, then connect any AI agent via MCP to their Salesforce org."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Install Package and Implement First MCP Tool (Priority: P1)

A Salesforce developer installs the second-generation unlocked package into their org. Using the framework's provided base classes and interfaces, they implement a custom MCP Tool — for example, a "query accounts" tool that accepts search parameters and returns matching Salesforce Account records. The developer writes an Apex class that extends the framework's tool interface, defines the tool's name, input schema, and execution logic. After deploying, the tool is automatically discoverable by any MCP client that connects.

**Why this priority**: Tools are the core value proposition of MCP — they enable AI agents to take actions within Salesforce. Without the ability to implement at least one tool, the entire package has no utility.

**Independent Test**: Can be fully tested by installing the package in a scratch org, creating a single Apex tool class, deploying it, and verifying the tool appears in the MCP `tools/list` response and executes correctly via `tools/call`.

**Acceptance Scenarios**:

1. **Given** a Salesforce org with the package installed, **When** a developer creates an Apex class implementing the tool interface with a name, description, and input schema, and registers it via the programmatic registry API, **Then** the tool is listed in the `tools/list` MCP response with correct metadata.
2. **Given** a registered tool, **When** an MCP client sends a `tools/call` request with valid arguments, **Then** the tool executes the Apex logic and returns the result in MCP-compliant content format.
3. **Given** a registered tool, **When** an MCP client sends a `tools/call` request with invalid or missing arguments, **Then** the system returns an MCP-compliant error result with `isError: true` and a descriptive message.
4. **Given** a registered tool, **When** the tool's Apex execution throws a catchable exception, **Then** the Apex framework catches it and returns an MCP error result (`isError: true`) with the exception message. **When** the tool triggers an uncatchable `System.LimitException` (governor limits), **Then** the proxy detects the non-JSON / HTTP 500 response from Salesforce and translates it into an MCP-compliant error result with a descriptive message. Neither case crashes the server session.

---

### User Story 2 - Connect AI Agent via MCP and Use Salesforce Tools (Priority: P2)

A business user's AI agent (e.g., Claude, ChatGPT, or a custom agent) connects to the Salesforce org via the MCP protocol. The agent performs the initialization handshake, discovers available tools, resources, and prompts, and then invokes tools to interact with Salesforce data on behalf of the user. The TypeScript proxy bridges the HTTP transport (from the AI agent) to the Salesforce-hosted MCP server, handling protocol translation and session management.

**Why this priority**: This is the end-to-end value delivery — without the proxy and transport layer working, no external agent can reach the Apex-based MCP server. This validates the full chain from AI agent through the proxy to Salesforce and back.

**Independent Test**: Can be fully tested by starting the TypeScript proxy, pointing an MCP client (like MCP Inspector) at it, completing the initialization handshake, and calling a tool that queries Salesforce data.

**Acceptance Scenarios**:

1. **Given** a running TypeScript proxy connected to a Salesforce org, **When** an MCP client sends an `initialize` request, **Then** the server responds with its protocol version, capabilities (tools, resources, prompts as applicable), and server info.
2. **Given** a completed initialization handshake, **When** the client sends `tools/list`, **Then** the server returns all registered Apex tools with their names, descriptions, and input schemas.
3. **Given** a completed initialization, **When** the client calls a tool that queries Salesforce records, **Then** the response contains the queried data in MCP-compliant content format within acceptable latency.
4. **Given** an active session, **When** the MCP client disconnects or the session times out, **Then** the server cleans up the session gracefully without resource leaks.

---

### User Story 3 - Implement MCP Resources to Expose Salesforce Data (Priority: P3)

A developer implements MCP Resources to expose read-only Salesforce data to AI agents — for example, exposing the org's custom object schema, a knowledge base, or configuration metadata. The developer creates an Apex class implementing the resource interface, defining a URI, name, description, and read logic. AI agents can then discover and read these resources to gain context about the Salesforce environment.

**Why this priority**: Resources complement tools by providing contextual data that AI agents need to make informed decisions. However, tools alone can deliver core functionality, making resources a valuable but secondary capability.

**Independent Test**: Can be fully tested by creating an Apex resource class, deploying it, and verifying it appears in `resources/list` and returns correct content via `resources/read`.

**Acceptance Scenarios**:

1. **Given** a Salesforce org with the package installed, **When** a developer creates an Apex class implementing the resource interface with a URI, name, and read logic, **Then** the resource appears in the `resources/list` MCP response.
2. **Given** a registered resource, **When** an MCP client sends `resources/read` with the resource URI, **Then** the server returns the resource content (text or binary) in MCP-compliant format.
3. **Given** a resource that depends on dynamic Salesforce data, **When** the underlying data changes, **Then** subsequent `resources/read` calls return the updated content.

---

### User Story 4 - Implement MCP Prompts as Reusable Templates (Priority: P4)

A developer implements MCP Prompts — pre-defined prompt templates that guide AI agents through common Salesforce workflows. For example, a "summarize opportunity" prompt that accepts an Opportunity ID and returns a structured prompt with context. The developer creates an Apex class implementing the prompt interface, defining arguments and message generation logic.

**Why this priority**: Prompts are user-controlled interaction patterns that enhance the agent experience but are not required for basic tool-based functionality.

**Independent Test**: Can be fully tested by creating an Apex prompt class, deploying it, and verifying it appears in `prompts/list` and returns correctly formatted messages via `prompts/get`.

**Acceptance Scenarios**:

1. **Given** a Salesforce org with the package installed, **When** a developer creates an Apex class implementing the prompt interface with a name, description, and arguments, **Then** the prompt appears in the `prompts/list` MCP response.
2. **Given** a registered prompt, **When** an MCP client sends `prompts/get` with the prompt name and required arguments, **Then** the server returns an array of prompt messages with correct roles and content.
3. **Given** a prompt with required arguments, **When** an MCP client sends `prompts/get` without the required arguments, **Then** the server returns an appropriate error.

---

### User Story 5 - Test MCP Implementation with Inspector (Priority: P5)

A developer uses the MCP Inspector to interactively test and debug their MCP server implementation. They launch the TypeScript proxy, connect the Inspector to it, and verify that all their custom tools, resources, and prompts work correctly. The Inspector shows the initialization handshake, capability negotiation, and allows interactive testing of each feature.

**Why this priority**: Testing is essential for quality but is a development-time concern, not an end-user-facing feature. The MCP Inspector is the prescribed testing tool per the MCP specification.

**Independent Test**: Can be fully tested by running the Inspector against the proxy, verifying all registered capabilities appear, and executing sample tool calls.

**Acceptance Scenarios**:

1. **Given** a running TypeScript proxy, **When** a developer runs `npx @modelcontextprotocol/inspector` and connects to the proxy, **Then** the Inspector completes the initialization handshake and displays available capabilities.
2. **Given** a connected Inspector session, **When** the developer selects a tool and provides test arguments, **Then** the tool executes and the Inspector displays the result.
3. **Given** a connected Inspector session, **When** the developer navigates to the Resources tab, **Then** all registered resources are listed and can be read.
4. **Given** a connected Inspector session, **When** the developer provides invalid inputs, **Then** the server returns properly formatted errors that the Inspector displays.

---

### User Story 6 - Secure MCP Access with Authentication (Priority: P6)

An administrator configures authentication so that only authorized AI agents can connect to the Salesforce MCP server. The system leverages Salesforce's built-in OAuth 2.0 / Connected App infrastructure for authentication, and the MCP authorization flow follows the specification's OAuth 2.1-based model. Only authenticated clients with valid access tokens can invoke tools or read resources.

**Why this priority**: Security is critical for production use but the core framework must work first. Authentication can be layered on after the protocol and capabilities are functional.

**Independent Test**: Can be fully tested by attempting to connect without valid credentials (expecting rejection) and with valid credentials (expecting success).

**Acceptance Scenarios**:

1. **Given** an MCP server with authentication enabled, **When** an unauthenticated client sends a request, **Then** the server responds with a `401 Unauthorized` status with appropriate OAuth challenge headers.
2. **Given** a valid OAuth access token, **When** a client includes it in the `Authorization: Bearer` header, **Then** the server accepts the request and processes it normally.
3. **Given** an expired or revoked access token, **When** a client sends a request, **Then** the server rejects the request with an appropriate error.

---

### Edge Cases

- What happens when a tool exceeds Salesforce Apex governor limits during execution (CPU time, SOQL queries, heap size)? → The Apex transaction terminates with HTTP 500; the proxy detects the non-JSON response and returns an MCP-compliant error result to the client.
- How does the system handle concurrent MCP sessions from multiple AI agents targeting the same org?
- What happens when a tool's Apex implementation references custom objects or fields that don't exist in the subscriber's org?
- How does the proxy handle network interruptions between the proxy and Salesforce? → No retry; the proxy immediately returns an MCP-compliant JSON-RPC error response to the client.
- What happens when the MCP client sends a request for a protocol version the server doesn't support?
- How does the system behave when the Salesforce org's API limits are exhausted?
- What happens when a tool returns data exceeding MCP message size limits?
- How does the system handle malformed JSON-RPC requests?

## Requirements *(mandatory)*

### Functional Requirements

**Core Protocol**
- **FR-001**: System MUST implement the MCP 2025-11-25 specification's JSON-RPC 2.0 message format, including requests, responses, and notifications.
- **FR-002**: System MUST implement the MCP lifecycle: initialization handshake (capability negotiation), operation, and shutdown.
- **FR-003**: System MUST respond to `initialize` requests with the server's protocol version (`2025-11-25`), declared capabilities, and server information.
- **FR-004**: System MUST support the `ping` method as an end-to-end health check — the proxy forwards the ping to the Salesforce Apex endpoint and returns the response, confirming full connectivity through to the org.
- **FR-005**: System MUST return standard JSON-RPC error codes for protocol errors (e.g., `-32601` for method not found, `-32602` for invalid params, `-32700` for parse errors).

**Tools Capability**
- **FR-006**: System MUST provide an Apex interface/base class that developers extend to implement custom MCP tools. The tool interface MUST include: (1) a method that returns the input schema as a `Map<String, Object>` mirroring JSON Schema structure, (2) a mandatory validate method that receives arguments as `Map<String, Object>` — the framework calls this before execution and every tool MUST implement it, and (3) an execute method that receives the validated tool arguments as `Map<String, Object>`. The framework does not perform JSON Schema validation itself; validation logic is the developer's responsibility but the framework enforces that it exists via the interface contract.
- **FR-007**: System MUST provide a programmatic registration API (e.g., `McpServer.registerTool(...)`) that developers call within their own `@RestResource` endpoint class to register tool implementations before delegating to the framework's request handler (e.g., `McpServer.handleRequest()`). Because Apex is stateless, registration occurs on every incoming request. This pattern allows subscribers to define multiple independent MCP endpoints with different capability sets.
- **FR-008**: System MUST respond to `tools/list` requests with all registered tools, including name, description, and JSON Schema for input parameters.
- **FR-009**: System MUST respond to `tools/call` requests by routing to the correct tool implementation, calling the tool's mandatory validate method with deserialized arguments first, and only if validation passes, calling the execute method and returning the result. If validation fails, the framework MUST return an MCP-compliant error result (`isError: true`) with the validation error message without invoking execute.
- **FR-010**: System MUST support tool results containing text content, and optionally image/audio content as base64-encoded data.
- **FR-011**: System MUST distinguish between tool execution errors (`isError: true` in result) and protocol errors (JSON-RPC error responses).
- **FR-011a**: System MUST enforce unique names for tools, unique URIs for resources, and unique names for prompts. Attempting to register a duplicate MUST throw an Apex exception at registration time with a clear error message identifying the conflicting name/URI.

**Resources Capability**
- **FR-012**: System MUST provide an Apex interface/base class for implementing custom MCP resources.
- **FR-013**: System MUST respond to `resources/list` with all registered resources including URI, name, description, and MIME type.
- **FR-014**: System MUST respond to `resources/read` by routing to the correct resource implementation and returning content.
- **FR-015**: System MUST support both text and binary (base64-encoded) resource content.

**Prompts Capability**
- **FR-016**: System MUST provide an Apex interface/base class for implementing custom MCP prompts.
- **FR-017**: System MUST respond to `prompts/list` with all registered prompts including name, description, and argument definitions.
- **FR-018**: System MUST respond to `prompts/get` by routing to the correct prompt implementation and returning formatted messages.

**TypeScript HTTP-to-Stdio Proxy**
- **FR-019**: System MUST include a TypeScript-based proxy that accepts MCP client connections via stdio and forwards JSON-RPC messages to a subscriber-defined Salesforce Apex REST endpoint (`@RestResource`) acting as the JSON-RPC dispatcher. The proxy MUST accept the endpoint URL path as a configuration parameter, since subscribers may define multiple MCP endpoints.
- **FR-020**: The proxy MUST handle all session management, including assigning and validating `MCP-Session-Id` headers, tracking protocol version, and managing session lifecycle. The Apex REST endpoint is stateless and does not store or validate session state.
- **FR-021**: The proxy MUST validate the `MCP-Protocol-Version` header on all incoming requests.
- **FR-022**: The proxy MUST support stdio transport on its client-facing side so it can be launched by MCP clients as a subprocess.
- **FR-023**: The proxy MUST relay JSON-RPC messages between the MCP client and the Salesforce Apex server with minimal latency overhead.
- **FR-023a**: The proxy MUST detect non-JSON or HTTP error responses from the Salesforce endpoint (e.g., HTTP 500 from uncatchable `System.LimitException`) and translate them into MCP-compliant JSON-RPC error responses with a descriptive error message, rather than forwarding raw HTTP errors to the client.
- **FR-023b**: The proxy MUST authenticate to the Salesforce org via the OAuth 2.0 Client Credentials flow at startup, using a pre-configured Salesforce Connected App. The proxy exchanges client credentials for an access token without interactive user involvement.
- **FR-023c**: The proxy MUST cache the obtained OAuth access token and automatically re-authenticate via client credentials when it expires.

**Packaging**
- **FR-024**: System MUST be distributed as a Salesforce Second Generation Unlocked Package (2GP, no namespace).
- **FR-025**: The package MUST expose tool, resource, and prompt interfaces as `public` Apex classes (virtual/abstract as appropriate) so subscribers can extend them.
- **FR-026**: The package MUST include all necessary Apex classes for the MCP server framework to function after installation. No Custom Metadata Types or Custom Settings are used; all framework configuration and behavior is resolved entirely in Apex code.

**Out of Scope (v1)**
- Logging capability (server→client log messages via `notifications/message`)
- List-changed notifications (`notifications/tools/list_changed`, `notifications/resources/list_changed`, `notifications/prompts/list_changed`)
- Completions / argument autocomplete (`completion/complete`)
- Sampling (server-initiated LLM requests via `sampling/createMessage`)
- Roots (`roots/list` and `notifications/roots/list_changed`)
- Resource templates (URI template discovery and expansion)
- Resource subscriptions (`resources/subscribe`, `resources/unsubscribe`, `notifications/resources/updated`)
- Per-tool/resource/prompt authorization scoping (connection-level auth only in v1)
- Streamable HTTP transport on the proxy's client-facing side (stdio only in v1; remote/cloud agent connectivity deferred to v2)
- Request cancellation (`notifications/cancelled`) — Apex transactions cannot be reliably aborted once Salesforce begins processing; deferred to v2
- Progress reporting (`notifications/progress`) — Apex REST is synchronous request/response; no mechanism to stream intermediate notifications during a running transaction; deferred to v2

**Authentication**
- **FR-027**: System MUST support authentication via OAuth 2.0 access tokens, leveraging Salesforce Connected Apps as the authorization mechanism. In v1, a valid token grants access to all tools, resources, and prompts registered on the endpoint (connection-level authorization). Per-tool scoping is deferred to a future version.
- **FR-028**: System MUST reject unauthenticated requests with `401 Unauthorized` and appropriate challenge headers when authentication is required.

**Observability**
- **FR-032**: The TypeScript proxy MUST emit log output to stdout/stderr with a configurable log level (e.g., debug, info, warn, error).
- **FR-033**: The Apex framework MUST use Salesforce platform debug logs (`System.debug`) with appropriate log levels for request routing, registration events, and error conditions. No custom log object is required for v1.

**Testing**
- **FR-029**: The package MUST include comprehensive Apex unit tests achieving at minimum 75% code coverage (required for unlocked package version creation), targeting 90%+ coverage.
- **FR-030**: The system MUST be testable end-to-end using the MCP Inspector (`npx @modelcontextprotocol/inspector`).
- **FR-031**: The system MUST include example/sample tool, resource, and prompt implementations for developers to reference.

### Key Entities

- **MCP Server Session**: Represents an active connection between an MCP client and the Salesforce MCP server. Managed entirely by the TypeScript proxy (not Salesforce). The proxy tracks protocol version, negotiated capabilities, and session lifecycle (initializing, operational, closed). The Apex REST endpoint is stateless — it receives and responds to individual JSON-RPC messages with no cross-request session awareness.
- **Tool Definition**: A registered tool with a unique name, human-readable description, JSON Schema for input parameters (defined as `Map<String, Object>` mirroring JSON Schema structure), and a reference to the implementing Apex class.
- **Resource Definition**: A registered resource with a unique URI, name, description, MIME type, and a reference to the implementing Apex class.
- **Prompt Definition**: A registered prompt with a unique name, description, argument definitions, and a reference to the implementing Apex class that generates prompt messages.
- **Tool Result**: The output of a tool invocation, containing an array of content blocks (text, image, audio) and an optional error flag.
- **Prompt Message**: A message within a prompt response, with a role (user/assistant) and content.
- **JSON-RPC Envelope**: The standard message wrapper containing jsonrpc version, optional id, method name, and params/result/error.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer with Salesforce experience can install the package and implement their first working MCP tool within 30 minutes, following the provided documentation and examples.
- **SC-002**: All registered tools, resources, and prompts are discoverable by the MCP Inspector with correct metadata within 5 seconds of completing the initialization handshake.
- **SC-003**: MCP tool invocations complete round-trip (client request through proxy to Salesforce Apex execution and back) within 5 seconds under normal conditions, excluding Salesforce API latency.
- **SC-004**: The system handles at least 10 concurrent MCP sessions without session cross-contamination or degradation.
- **SC-005**: 100% of JSON-RPC protocol errors return spec-compliant error responses with correct error codes.
- **SC-006**: Apex unit test coverage for the packaged framework exceeds 90%.
- **SC-007**: The MCP Inspector can successfully connect, initialize, list capabilities, call tools, read resources, and get prompts without protocol errors.
- **SC-008**: A developer can implement all three MCP capability types (tool, resource, prompt) using only the package's public interfaces and the provided documentation, without needing to understand MCP protocol internals.

## Assumptions

- Developers installing the package have working knowledge of Salesforce Apex development, including familiarity with deploying custom classes and managing connected apps.
- The subscriber org has API access enabled (API calls are available and not permanently exhausted).
- The TypeScript proxy runs in a Node.js environment on the same network or a network with reliable connectivity to the Salesforce org (standard internet latency is acceptable).
- AI agents connecting via MCP comply with the MCP 2025-11-25 specification — the server does not need to support older protocol versions in v1.
- The package is an unlocked package with no namespace. Classes are referenced directly by name (e.g., `McpServer`, not `mcp.McpServer`). Unlocked packages do not provide IP protection or enforce API versioning — this is acceptable for v1.
- Salesforce's existing OAuth 2.0 Connected App infrastructure is sufficient for MCP authentication needs — no custom authorization server is required. The proxy uses the OAuth 2.0 Client Credentials flow to authenticate to Salesforce, requiring a pre-configured Connected App with client credentials (client ID and secret) in the subscriber org.
- Governor limits are the responsibility of the tool/resource/prompt implementer (the subscriber developer), not the framework — the framework documents best practices but cannot override platform limits.
- The proxy communicates with a subscriber-defined `@RestResource` Apex REST endpoint that acts as a JSON-RPC dispatcher. The proxy POSTs each JSON-RPC message as the HTTP body; the Apex endpoint deserializes, routes to the correct handler, and returns the JSON-RPC response. Subscribers may create multiple independent MCP endpoints with different capability registrations.
- Binary content (images, audio) in MCP responses will be base64-encoded as strings, within Salesforce's Apex heap size limits.
- The MCP Inspector (current version) is the primary external testing tool; compatibility with other MCP clients is expected but not individually validated in v1.

## Clarifications

### Session 2026-03-28

- Q: Which optional MCP 2025-11-25 capabilities beyond tools, resources, and prompts are in-scope for v1? → A: None — v1 includes only the core three capabilities (tools, resources, prompts). All optional features (logging, notifications, completions, sampling, roots, resource templates, subscriptions) are explicitly out of scope.
- Q: How should the framework discover developer-implemented tool, resource, and prompt classes? → A: Programmatic Apex-based registry — developers call a registration method (e.g., `McpServer.registerTool(...)`) from an initialization class to register their implementations.
- Q: What communication pattern should the TS proxy use to reach the Apex MCP server? → A: Single Apex REST endpoint — one `@RestResource` class receives all JSON-RPC messages as HTTP POST bodies and dispatches internally to the correct handler.
- Q: What level of observability should the framework provide in v1? → A: Minimal — Apex platform debug logs (`System.debug`) plus proxy console output (stdout/stderr) with configurable log level. No custom log objects or structured tracing for v1.
- Q: How should the framework handle duplicate tool/resource/prompt name registration? → A: Reject duplicate — throw an Apex exception at registration time with a clear error message identifying the conflicting name/URI.
- Q: Where should MCP session state be stored between requests? → A: Proxy-side only — the proxy tracks all session state (protocol version, capabilities, lifecycle); the Apex REST endpoint is fully stateless per request with no session awareness.
- Q: How should the framework handle uncatchable Apex `System.LimitException` (governor limit violations)? → A: Framework catches all catchable exceptions and returns MCP error results; the proxy detects non-JSON or HTTP 500 responses from Salesforce and translates them into MCP-compliant error results with a descriptive message.
- Q: How should the proxy authenticate to the Salesforce REST endpoint? → A: Client Credentials flow — the proxy authenticates using client ID and secret from a pre-configured Connected App, with no interactive user involvement.
- Q: What package type and namespace should be used? → A: Unlocked package (no namespace). Not a managed package — no namespace prefix on classes.
- Q: How should the proxy handle network interruptions or HTTP failures between itself and Salesforce? → A: No retry — immediately return an MCP-compliant error to the client on any Salesforce HTTP failure. No retry logic in v1.
- Q: Should the package use Custom Metadata Types or Custom Settings for configuration? → A: No — no Custom Metadata Types or Custom Settings. All configuration and framework behavior is resolved entirely in Apex code.
- Q: Which OAuth flow should the proxy use for Salesforce authentication? → A: Client Credentials flow (not device flow) — server-to-server authentication without interactive user involvement.
- Q: Who owns the `@RestResource` endpoint — the package or the subscriber developer? → A: Developer-owned — the subscriber writes their own `@RestResource`, calls framework registration methods inline, then delegates to `McpServer.handleRequest()`. This allows multiple independent MCP endpoints with different capability sets.
- Q: How should developers define tool input schemas in Apex? → A: Map-based — developers return a `Map<String, Object>` mirroring JSON Schema structure. Tool arguments are received as `Map<String, Object>` from deserialized JSON-RPC params.
- Q: Should the framework validate tool arguments against the declared schema? → A: Framework-enforced developer validation — the framework does not perform JSON Schema validation itself (Apex lacks good tooling), but the tool interface mandates a validate method that every tool MUST implement. The framework calls validate before execute and translates validation failures into MCP error results (`isError: true`).
- Q: Should per-tool authorization scoping (403 for out-of-scope tools) be in v1? → A: No — connection-level auth only for v1. A valid client credentials token grants access to all registered tools/resources/prompts on the endpoint. Developers can achieve endpoint-level separation by deploying multiple `@RestResource` endpoints with different capability sets. Per-tool scoping deferred to future version.

### Session 2026-03-30

- Q: Should the proxy support only stdio transport in v1, or also Streamable HTTP? → A: Stdio only — remote/cloud agent connectivity deferred to v2.
- Q: Should request cancellation (`notifications/cancelled`) be supported in v1? → A: Out of scope for v1 — Apex transactions cannot be reliably aborted mid-execution; added to explicit out-of-scope list.
- Q: Should `ping` be a proxy-only liveness check or an end-to-end Salesforce connectivity check? → A: End-to-end — proxy forwards ping to the Apex endpoint, confirming full Salesforce connectivity.
- Q: Should progress reporting (`notifications/progress`) be supported in v1? → A: Out of scope for v1 — Apex REST is synchronous with no mechanism for mid-transaction streaming; added to explicit out-of-scope list.
