# Feature Specification: MCP Server Framework for Salesforce Apex

**Feature Branch**: `001-apex-mcp-server`
**Created**: 2026-03-28
**Status**: Draft
**Input**: User description: "Implement MCP in Apex language with local TS HTTP-to-stdio proxy. Second generation Salesforce packages. Latest MCP specification (2025-11-25). With broad testing in Apex, and outside invocation using MCP Inspector. Customers install the 2GP package, implement desired tools/resources/prompts using the package framework, then connect any AI agent via MCP to their Salesforce org."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Install Package and Implement First MCP Tool (Priority: P1)

A Salesforce developer installs the second-generation managed package into their org. Using the framework's provided base classes and interfaces, they implement a custom MCP Tool — for example, a "query accounts" tool that accepts search parameters and returns matching Salesforce Account records. The developer writes an Apex class that extends the framework's tool interface, defines the tool's name, input schema, and execution logic. After deploying, the tool is automatically discoverable by any MCP client that connects.

**Why this priority**: Tools are the core value proposition of MCP — they enable AI agents to take actions within Salesforce. Without the ability to implement at least one tool, the entire package has no utility.

**Independent Test**: Can be fully tested by installing the package in a scratch org, creating a single Apex tool class, deploying it, and verifying the tool appears in the MCP `tools/list` response and executes correctly via `tools/call`.

**Acceptance Scenarios**:

1. **Given** a Salesforce org with the package installed, **When** a developer creates an Apex class implementing the tool interface with a name, description, and input schema, **Then** the tool is listed in the `tools/list` MCP response with correct metadata.
2. **Given** a registered tool, **When** an MCP client sends a `tools/call` request with valid arguments, **Then** the tool executes the Apex logic and returns the result in MCP-compliant content format.
3. **Given** a registered tool, **When** an MCP client sends a `tools/call` request with invalid or missing arguments, **Then** the system returns an MCP-compliant error result with `isError: true` and a descriptive message.
4. **Given** a registered tool, **When** the tool's Apex execution throws an unhandled exception, **Then** the system catches the exception, returns an MCP error result, and does not crash the server session.

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
4. **Given** a valid token with limited scope, **When** a client attempts to invoke a tool outside its permitted scope, **Then** the server returns a `403 Forbidden` with `insufficient_scope` error.

---

### Edge Cases

- What happens when a tool exceeds Salesforce Apex governor limits during execution (CPU time, SOQL queries, heap size)?
- How does the system handle concurrent MCP sessions from multiple AI agents targeting the same org?
- What happens when a tool's Apex implementation references custom objects or fields that don't exist in the subscriber's org?
- How does the proxy handle network interruptions between the proxy and Salesforce?
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
- **FR-004**: System MUST support the `ping` method for connection health checks.
- **FR-005**: System MUST return standard JSON-RPC error codes for protocol errors (e.g., `-32601` for method not found, `-32602` for invalid params, `-32700` for parse errors).

**Tools Capability**
- **FR-006**: System MUST provide an Apex interface/base class that developers extend to implement custom MCP tools.
- **FR-007**: System MUST automatically discover and register all Apex classes implementing the tool interface at server startup.
- **FR-008**: System MUST respond to `tools/list` requests with all registered tools, including name, description, and JSON Schema for input parameters.
- **FR-009**: System MUST respond to `tools/call` requests by routing to the correct tool implementation, passing deserialized arguments, and returning the result.
- **FR-010**: System MUST support tool results containing text content, and optionally image/audio content as base64-encoded data.
- **FR-011**: System MUST distinguish between tool execution errors (`isError: true` in result) and protocol errors (JSON-RPC error responses).

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
- **FR-019**: System MUST include a TypeScript-based proxy that exposes an HTTP endpoint and translates MCP Streamable HTTP transport to communication with the Salesforce-hosted Apex MCP server.
- **FR-020**: The proxy MUST handle session management, including assigning and validating `MCP-Session-Id` headers.
- **FR-021**: The proxy MUST validate the `MCP-Protocol-Version` header on all incoming requests.
- **FR-022**: The proxy MUST support stdio transport on its client-facing side so it can be launched by MCP clients as a subprocess.
- **FR-023**: The proxy MUST relay JSON-RPC messages between the MCP client and the Salesforce Apex server with minimal latency overhead.

**Packaging**
- **FR-024**: System MUST be distributed as a Salesforce Second Generation Managed Package (2GP).
- **FR-025**: The package MUST expose tool, resource, and prompt interfaces as `global` Apex classes so subscribers can extend them.
- **FR-026**: The package MUST include all necessary custom metadata, classes, and configuration for the MCP server framework to function after installation.

**Authentication**
- **FR-027**: System MUST support authentication via OAuth 2.0 access tokens, leveraging Salesforce Connected Apps as the authorization mechanism.
- **FR-028**: System MUST reject unauthenticated requests with `401 Unauthorized` and appropriate challenge headers when authentication is required.

**Testing**
- **FR-029**: The package MUST include comprehensive Apex unit tests achieving at minimum 75% code coverage (required for 2GP promotion), targeting 90%+ coverage.
- **FR-030**: The system MUST be testable end-to-end using the MCP Inspector (`npx @modelcontextprotocol/inspector`).
- **FR-031**: The system MUST include example/sample tool, resource, and prompt implementations for developers to reference.

### Key Entities

- **MCP Server Session**: Represents an active connection between an MCP client and the Salesforce MCP server. Tracks protocol version, negotiated capabilities, and session state (initializing, operational, closed).
- **Tool Definition**: A registered tool with a unique name, human-readable description, JSON Schema for input parameters, optional output schema, and a reference to the implementing Apex class.
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
- The package uses a managed namespace to protect intellectual property and provide a stable API contract for subscribers.
- Salesforce's existing OAuth 2.0 Connected App infrastructure is sufficient for MCP authentication needs — no custom authorization server is required.
- Governor limits are the responsibility of the tool/resource/prompt implementer (the subscriber developer), not the framework — the framework documents best practices but cannot override platform limits.
- The proxy communicates with Salesforce via REST API (Apex REST endpoints or similar), not via Salesforce's internal messaging systems.
- Binary content (images, audio) in MCP responses will be base64-encoded as strings, within Salesforce's Apex heap size limits.
- The MCP Inspector (current version) is the primary external testing tool; compatibility with other MCP clients is expected but not individually validated in v1.
