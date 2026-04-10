# Data Model: MCP Server Framework for Salesforce Apex

**Feature**: 001-apex-mcp-server | **Date**: 2026-03-30

## Overview

This data model describes the Apex class hierarchy and TypeScript interfaces that form the framework's public and internal type system. There is no persistent storage (no custom objects, custom metadata, or custom settings). All entities exist in-memory during a single Apex transaction or within the TypeScript proxy's process lifetime.

---

## Apex Entities

### JSON-RPC 2.0 Core (`force-app/main/json-rpc/classes/`)

#### JsonRpcParamsBase (abstract)

Base class for all typed JSON-RPC parameter objects.

| Field | Type | Description |
|---|---|---|
| *(none — abstract base)* | | Subclasses define typed fields |

- **Validation**: Virtual `validate()` method — subclasses override to provide domain-specific validation.
- **State transitions**: None (stateless DTO).
- **Relationships**: Extended by all MCP `*RpcParams` classes.

#### JsonRpcResultBase (abstract)

Base class for all typed JSON-RPC result objects.

| Field | Type | Description |
|---|---|---|
| *(none — abstract base)* | | Subclasses define typed fields |

- **Relationships**: Extended by all MCP `*Result` classes.

#### JsonRpcError

Standard JSON-RPC error object with factory methods for standard codes.

| Field | Type | Required | Description |
|---|---|---|---|
| code | Integer | Yes | JSON-RPC error code |
| message | String | Yes | Human-readable error description |
| data | Object | No | Additional error data |

- **Factory methods**: `parseError()` (-32700), `invalidRequest()` (-32600), `methodNotFound()` (-32601), `invalidParams()` (-32602), `internalError()` (-32603).

#### JsonRpcResponse

Single JSON-RPC response envelope.

| Field | Type | Required | Description |
|---|---|---|---|
| id | JsonRpcIdValue | Yes | Request ID (string, integer, or null) |
| hasResult | Boolean | Internal | Discriminator: true = success, false = error |
| result | Object | Conditional | Present when hasResult is true |
| error | JsonRpcError | Conditional | Present when hasResult is false |

#### JsonRpcExecutionResult

Container wrapping one or more `JsonRpcResponse` objects.

| Field | Type | Description |
|---|---|---|
| hasResponse | Boolean | False for notifications (no response needed) |
| isBatch | Boolean | True when processing a JSON-RPC batch array |
| responses | List&lt;JsonRpcResponse&gt; | The response(s) |

- **Methods**: `toJson()` — manually builds JSON string using `JSON.serialize(result, true)` for null-clean wire output.

#### JsonRpcInvocationContext

Per-request context passed to method handlers.

| Field | Type | Description |
|---|---|---|
| methodName | String | The JSON-RPC method being invoked |
| requestId | JsonRpcIdValue | The request ID |
| rawRequest | Map&lt;String, Object&gt; | The full deserialized JSON-RPC request object |
| batchIndex | Integer | Index within a batch (0 for single requests) |

#### JsonRpcMethodHandler (abstract)

Base handler that method implementations extend.

| Constructor Param | Type | Description |
|---|---|---|
| method | String | The JSON-RPC method name to handle |
| paramsType | System.Type | The Apex type for deserialized params |
| resultType | System.Type | The Apex type for the result |

- **Abstract method**: `invoke(JsonRpcInvocationContext context)` — returns `JsonRpcResponse`.
- **Relationships**: Extended by all MCP handler classes (InitializeHandler, ToolsListHandler, etc.).

#### JsonRpcModule

Handler registry — maps method names to handlers.

| Method | Description |
|---|---|
| register(JsonRpcMethodHandler handler) | Add a handler for a method |
| getHandler(String method) | Look up handler by method name |

#### JsonRpcModuleBuilder (abstract)

Fluent builder for configuring a module.

- **Abstract method**: `configure(JsonRpcModule module)` — subclass registers handlers.
- **Method**: `build()` — returns configured `JsonRpcModule`.

#### JsonRpcServiceRuntime

Static dispatcher — entry point for processing raw JSON strings.

| Method | Description |
|---|---|
| static execute(String json, JsonRpcModule module, JsonRpcServiceRuntimeOptions options) | Parse, route, execute, return result |

- **Inner exceptions**: `ParseFailureException`, `InvalidRequestException`, `MethodNotFoundException`, `InvalidParamsException`.

#### JsonRpcServiceRuntimeOptions

Configuration for the runtime.

| Field | Type | Description |
|---|---|---|
| exceptionMapper | JsonRpcExceptionMapper | Custom exception-to-error mapping |

#### JsonRpcExceptionMapper (interface)

Interface for custom exception handling.

| Method | Description |
|---|---|
| mapException(Exception e) | Convert an Apex exception to a JsonRpcError |

#### JsonRpcIdValue

Typed representation of a JSON-RPC ID (string, integer, or null).

---

### MCP 2025-11-25 Layer (`force-app/main/mcp/classes/`)

#### McpServer

Main entry point — the programmatic registration API and request dispatcher.

| Method | Description |
|---|---|
| registerTool(McpToolDefinition tool) | Register a tool; throws on duplicate name |
| registerResource(McpResourceDefinition resource) | Register a resource; throws on duplicate URI |
| registerPrompt(McpPromptDefinition prompt) | Register a prompt; throws on duplicate name |
| handleRequest(RestRequest req, RestResponse res) | Process an incoming JSON-RPC request |

- **Validation**: Unique name/URI enforcement at registration time (FR-011a).
- **Relationships**: Subscriber `@RestResource` endpoints create an `McpServer`, register capabilities, then call `handleRequest()`.

#### McpToolDefinition

Defines a tool that subscribers implement.

| Field | Type | Required | Description |
|---|---|---|---|
| name | String | Yes | Unique tool identifier |
| description | String | No | Human-readable description |
| annotations | McpToolAnnotations | No | Tool metadata (read-only hint, destructive hint, etc.) |

| Abstract Method | Return Type | Description |
|---|---|---|
| inputSchema() | Map&lt;String, Object&gt; | JSON Schema for input parameters |
| validate(Map&lt;String, Object&gt; arguments) | void | Validate arguments; throw on failure |
| execute(Map&lt;String, Object&gt; arguments) | McpToolResult | Execute tool logic |

- **State transitions**: None (stateless — instantiated per request).
- **Relationships**: Registered in `McpServer`; invoked by `McpToolExecutor`.

#### McpToolResult

Result of a tool invocation.

| Field | Type | Required | Description |
|---|---|---|---|
| content | List&lt;McpTextContent&gt; | Yes | Array of content blocks |
| isError | Boolean | No | True if the tool encountered an error |

#### McpToolAnnotations / McpToolAnnotationsWire

Tool metadata for client hints.

| Field | Type | Description |
|---|---|---|
| readOnlyHint | Boolean | Tool does not modify data |
| destructiveHint | Boolean | Tool may delete data |
| idempotentHint | Boolean | Repeated calls produce same result |
| openWorldHint | Boolean | Tool interacts with external systems |

#### McpResourceDefinition

Defines a resource that subscribers implement.

| Field | Type | Required | Description |
|---|---|---|---|
| uri | String | Yes | Unique resource URI |
| name | String | Yes | Human-readable name |
| description | String | No | Description |
| mimeType | String | No | Content MIME type |

| Abstract Method | Return Type | Description |
|---|---|---|
| read() | McpResourceResult | Read resource content |

- **Relationships**: Registered in `McpServer`; invoked by `McpResourceExecutor`.

#### McpResourceResult

Result of a resource read operation.

| Field | Type | Description |
|---|---|---|
| contents | List&lt;McpResourceContentItem&gt; | Content items (text or blob) |

#### McpResourceContentItem

A single content item within a resource response.

| Field | Type | Description |
|---|---|---|
| uri | String | Resource URI |
| mimeType | String | Content MIME type |
| text | String | Text content (mutually exclusive with blob) |
| blob | String | Base64-encoded binary content (mutually exclusive with text) |

#### McpResourceTemplateDefinition

Defines a URI template for dynamic resource discovery.

| Field | Type | Required | Description |
|---|---|---|---|
| uriTemplate | String | Yes | RFC 6570 URI template |
| name | String | Yes | Human-readable name |
| description | String | No | Description |
| mimeType | String | No | Content MIME type |

| Abstract Method | Return Type | Description |
|---|---|---|
| read(Map&lt;String, String&gt; templateArguments) | McpResourceResult | Read resource by template args |

#### McpPromptDefinition

Defines a prompt that subscribers implement.

| Field | Type | Required | Description |
|---|---|---|---|
| name | String | Yes | Unique prompt identifier |
| description | String | No | Human-readable description |
| arguments | List&lt;McpPromptArgumentDefinition&gt; | No | Prompt argument definitions |

| Abstract Method | Return Type | Description |
|---|---|---|
| get(Map&lt;String, String&gt; arguments) | McpPromptResult | Generate prompt messages |

- **Relationships**: Registered in `McpServer`; invoked by `McpPromptExecutor`.

#### McpPromptArgumentDefinition

Defines a prompt argument.

| Field | Type | Required | Description |
|---|---|---|---|
| name | String | Yes | Argument name |
| description | String | No | Argument description |
| required | Boolean | No | Whether the argument is required |

#### McpPromptResult

Result of a prompt get operation.

| Field | Type | Description |
|---|---|---|
| description | String | Description of the prompt |
| messages | List&lt;McpPromptMessage&gt; | Array of prompt messages |

#### McpPromptMessage

A message within a prompt response.

| Field | Type | Description |
|---|---|---|
| role | String | `"user"` or `"assistant"` |
| content | McpTextContent | The message content |

#### McpTextContent

Text content block used across tools, resources, and prompts.

| Field | Type | Description |
|---|---|---|
| type | String | Always `"text"` |
| text | String | The text content |

#### McpInitializeParams (extends JsonRpcParamsBase)

Typed params for the `initialize` request.

| Field | Type | Required | Description |
|---|---|---|---|
| protocolVersion | String | Yes | Client's MCP protocol version |
| capabilities | McpInitializeCapabilities | Yes | Client capabilities |
| clientInfo | McpInitializeClientInfo | Yes | Client implementation details |

#### McpInitializeResult (extends JsonRpcResultBase)

Result of the `initialize` request.

| Field | Type | Required | Description |
|---|---|---|---|
| protocolVersion | String | Yes | Server's MCP protocol version (`2025-11-25`) |
| capabilities | Map&lt;String, Object&gt; | Yes | Server capabilities |
| serverInfo | McpInitializeServerInfo | Yes | Server implementation details |
| instructions | String | No | Hints for the LLM |

#### McpInitializeCapabilities

Client capabilities received during initialization.

| Field | Type | Description |
|---|---|---|
| roots | McpInitializeCapabilityEntry | Roots capability |
| sampling | McpInitializeCapabilityEntry | Sampling capability |

#### McpInitializeClientInfo / McpInitializeServerInfo

Implementation metadata exchanged during initialization.

| Field | Type | Required | Description |
|---|---|---|---|
| name | String | Yes | Implementation name |
| version | String | No | Implementation version |

#### McpHttpTransport

Wraps Salesforce `RestRequest` / `RestResponse` for the framework.

| Method | Description |
|---|---|
| getRequestBody() | Extract raw JSON from the REST request |
| setResponseBody(String json) | Write JSON-RPC response to the REST response |

#### McpNamedArgumentsParams (extends JsonRpcParamsBase)

Params container for methods that use named arguments loaded from raw request.

| Method | Description |
|---|---|
| loadFromRaw(Map&lt;String, Object&gt; rawParams) | Load params from raw deserialized JSON |

- **Usage**: Used by `tools/call`, `prompts/get`, `resources/templates/call` handlers that need access to the dynamic `arguments` map.

#### McpJsonRpcModuleBuilder (extends JsonRpcModuleBuilder)

Configures all MCP method handlers in the JSON-RPC module.

| Registered Handlers | Method |
|---|---|
| InitializeHandler | `initialize` |
| PingHandler | `ping` |
| ToolsListHandler | `tools/list` |
| ToolsCallHandler | `tools/call` |
| ResourcesListHandler | `resources/list` |
| ResourcesReadHandler | `resources/read` |
| ResourcesTemplatesListHandler | `resources/templates/list` |
| ResourcesTemplatesCallHandler | `resources/templates/call` |
| PromptsListHandler | `prompts/list` |
| PromptsGetHandler | `prompts/get` |

#### McpJsonRpcExceptionMapper (implements JsonRpcExceptionMapper)

Maps MCP-specific exceptions to JSON-RPC error responses.

| Exception | JSON-RPC Error Code |
|---|---|
| McpInvalidParamsException | -32602 (Invalid params) |
| General Exception | -32603 (Internal error) |

---

## TypeScript Entities (`packages/salesforce-mcp-lib/src/`)

### Configuration (`config.ts` / `types.ts`)

#### BridgeConfig

| Field | Type | Required | Description |
|---|---|---|---|
| instanceUrl | string | Yes | Salesforce org My Domain URL |
| clientId | string | Yes | External Client App consumer key |
| clientSecret | string | Yes | External Client App consumer secret |
| endpoint | string | Yes | Subscriber's `@RestResource` URL path |
| logLevel | string | No | Logging verbosity (debug, info, warn, error) |

### Authentication (`oauth.ts` / `types.ts`)

#### OAuthTokenResponse

| Field | Type | Description |
|---|---|---|
| access_token | string | Bearer token for API calls |
| instance_url | string | Base URL for REST API calls |
| token_type | string | Always `"Bearer"` |
| id | string | Identity URL for the run-as user |
| issued_at | string | Unix timestamp (ms) when token was issued |

### Transport (`mcpBridge.ts` / `stdio.ts`)

#### McpSession (proxy-managed)

| Field | Type | Description |
|---|---|---|
| sessionId | string | Unique session identifier (crypto-random) |
| protocolVersion | string | Negotiated MCP protocol version |
| serverCapabilities | object | Server capabilities from initialize response |
| state | string | `"initializing"` / `"operational"` / `"closed"` |

### Errors (`errors.ts`)

| Error Class | Description |
|---|---|
| SalesforceAuthError | OAuth authentication failure |
| RemoteMcpError | Salesforce endpoint returned a non-JSON or HTTP error response |

---

## Entity Relationships

```text
McpServer
├── registers → McpToolDefinition[]       (1:N, unique by name)
│                └── produces → McpToolResult
│                     └── contains → McpTextContent[]
├── registers → McpResourceDefinition[]   (1:N, unique by URI)
│                └── produces → McpResourceResult
│                     └── contains → McpResourceContentItem[]
├── registers → McpPromptDefinition[]     (1:N, unique by name)
│                └── produces → McpPromptResult
│                     └── contains → McpPromptMessage[]
│                          └── contains → McpTextContent
├── uses → McpJsonRpcModuleBuilder
│           └── configures → JsonRpcModule
│                └── contains → JsonRpcMethodHandler[] (one per MCP method)
└── uses → McpHttpTransport (wraps RestRequest/RestResponse)

JsonRpcServiceRuntime
├── receives → raw JSON string
├── parses → JsonRpcInvocationContext
├── routes via → JsonRpcModule.getHandler()
├── delegates to → JsonRpcMethodHandler.invoke()
└── returns → JsonRpcExecutionResult
              └── contains → JsonRpcResponse[]
                   └── contains → result (Object) | error (JsonRpcError)

TypeScript Proxy (McpSession)
├── authenticates via → OAuthTokenResponse (client credentials flow)
├── receives from stdin → JSON-RPC messages
├── forwards via HTTP → Salesforce @RestResource endpoint
├── receives HTTP response → JSON-RPC result
└── writes to stdout → JSON-RPC response
```
