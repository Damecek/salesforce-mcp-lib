# Research: MCP Server Framework for Salesforce Apex

**Feature**: 001-apex-mcp-server | **Date**: 2026-03-30

## R1: MCP 2025-11-25 Protocol Wire Format

### Decision: Implement JSON-RPC 2.0 with MCP 2025-11-25 lifecycle, tools, resources, and prompts

**Rationale**: The MCP specification mandates strict JSON-RPC 2.0 compliance. The protocol defines a three-phase lifecycle (initializing, operational, shutdown) with capability negotiation at initialization. The server declares which capabilities it supports; clients only invoke methods for declared capabilities.

**Alternatives considered**: None — the specification is prescriptive.

### Key Findings

**Lifecycle**:
1. Client sends `initialize` with `protocolVersion`, `capabilities`, `clientInfo` (all required).
2. Server responds with `protocolVersion`, `capabilities`, `serverInfo` (all required), optional `instructions`.
3. Client sends `notifications/initialized` notification (no response).
4. Session becomes **operational**. Normal request/response exchange begins.
5. Shutdown via transport close (stdio) or HTTP DELETE (Streamable HTTP).

**Server capabilities object** (all fields optional; presence indicates support):
- `tools: { listChanged?: boolean }` — declare to enable `tools/list` and `tools/call`
- `resources: { subscribe?: boolean, listChanged?: boolean }` — declare to enable `resources/list` and `resources/read`
- `prompts: { listChanged?: boolean }` — declare to enable `prompts/list` and `prompts/get`
- `logging: {}` — out of scope for v1

**Tools wire format**:
- `tools/list` → returns `{ tools: Tool[], nextCursor?: string }`
- Tool shape: `{ name (required), inputSchema (required, type: "object"), title?, description?, outputSchema?, annotations?, icons? }`
- `tools/call` params: `{ name (required), arguments? (object) }`
- `CallToolResult`: `{ content: ContentBlock[] (required), isError?: boolean, structuredContent? }`
- Content block types: `text`, `image` (base64 + mimeType), `audio` (base64 + mimeType), `resource`

**Resources wire format**:
- `resources/list` → returns `{ resources: Resource[], nextCursor?: string }`
- Resource shape: `{ uri (required), name (required), title?, description?, mimeType?, icons? }`
- `resources/read` params: `{ uri (required) }`
- Response: `{ contents: [{ uri, mimeType?, text | blob }] }` — text content uses `text` field, binary uses `blob` (base64), never both

**Prompts wire format**:
- `prompts/list` → returns `{ prompts: Prompt[], nextCursor?: string }`
- Prompt shape: `{ name (required), title?, description?, arguments?: PromptArgument[], icons? }`
- `prompts/get` params: `{ name (required), arguments? (object) }`
- `GetPromptResult`: `{ description?, messages: PromptMessage[] (required) }`
- PromptMessage: `{ role: "user" | "assistant", content: ContentBlock }`

**Two-tier error model**:
- Protocol errors: JSON-RPC `error` field (`-32700` parse, `-32600` invalid request, `-32601` method not found, `-32602` invalid params, `-32603` internal)
- Tool execution errors: Normal `result` with `isError: true` — these are actionable for the LLM

**Ping**: `{ method: "ping" }` → responds with `{ result: {} }`

**Session management** (Streamable HTTP transport only; not applicable to stdio):
- `Mcp-Session-Id` header assigned by server in initialize response
- Client includes it in all subsequent requests
- Server returns 400 for missing header, 404 for terminated session

---

## R2: Apex Governor Limits Impact

### Decision: Framework must be minimal-overhead; document limits for subscriber developers; proxy handles uncatchable LimitException

**Rationale**: Apex governor limits are per-transaction and shared between the framework and subscriber tool code. The framework cannot override platform limits — it can only minimize its own footprint and document constraints.

**Alternatives considered**: Async execution (Queueable/Future) was rejected because `@RestResource` endpoints are synchronous and the response must be returned in the same transaction.

### Key Findings

**Critical limits per synchronous transaction**:

| Limit | Value | Impact |
|---|---|---|
| CPU time | 10,000 ms | Budget shared with tool logic; framework overhead must be minimal |
| Heap size | 6 MB | Constrains tool response sizes (SOQL results serialized as JSON) |
| SOQL queries | 100 | Shared budget; framework uses 0 SOQL queries |
| DML statements | 150 | Subscriber tools only; framework performs no DML |
| Callouts | 100 | Subscriber tools only; framework makes no callouts |

**Concurrent request limit**: Salesforce enforces 10 concurrent long-running requests per org. A request is "long-running" once it exceeds 5 seconds. With SC-004 targeting 10 concurrent MCP sessions, tools should aim for sub-5-second execution.

**System.LimitException**:
- Uncatchable in Apex — `try-catch(Exception)` does not intercept it
- Terminates the transaction immediately; rolls back all DML
- Salesforce returns HTTP 500 with body: `[{"message":"<stack trace>","errorCode":"APEX_ERROR"}]`
- Proxy detection strategy: check HTTP status (non-2xx), parse response, look for `APEX_ERROR`, translate to JSON-RPC `-32603` error

**JSON serialization considerations**:
- `JSON.deserializeUntyped()` maps to `Map<String, Object>` — JSON integers become `Integer` (or `Long` if large), decimals become `Decimal`
- `JSON.serialize(obj, true)` suppresses null fields — used for clean wire output
- No generics support in `JSON.deserialize()` — motivates the `Map<String, Object>` approach for tool arguments
- No runtime type introspection — framework cannot dynamically inspect subscriber class fields

**Preemptive limit checking**: `Limits.getCpuTime()`, `Limits.getHeapSize()`, `Limits.getQueries()` etc. are available but advisory only. Including them in framework overhead adds complexity without guarantees.

---

## R3: Salesforce OAuth 2.0 Client Credentials Flow

### Decision: Proxy authenticates via client credentials flow at startup; caches token; re-authenticates on 401

**Rationale**: Client credentials flow is the standard server-to-server authentication pattern for Salesforce. No interactive user involvement, which is required for a stdio proxy launched as a subprocess.

**Alternatives considered**: Device flow (rejected — requires interactive user approval, incompatible with stdio subprocess model), JWT bearer flow (rejected — requires certificate management, more complex setup for equivalent result).

### Key Findings

**Token endpoint**: `POST https://<MyDomain>.my.salesforce.com/services/oauth2/token`

**Request** (`application/x-www-form-urlencoded`):
- `grant_type=client_credentials`
- `client_id=<consumer_key>`
- `client_secret=<consumer_secret>`

**Response** (JSON, HTTP 200):
```json
{
  "access_token": "00D...!AQ...",
  "instance_url": "https://mycompany.my.salesforce.com",
  "token_type": "Bearer",
  "id": "https://login.salesforce.com/id/<orgId>/<userId>",
  "issued_at": "1679565776974"
}
```

**Key rules**:
- Use `instance_url` from response as base URL for all API calls (not the login domain)
- No refresh token is issued — re-authenticate by repeating the exchange
- Token lifetime governed by org session timeout (default ~2h, enforced max ~90 min for new orgs)

**Expired token detection**: HTTP 401 with body `[{"errorCode":"INVALID_SESSION_ID","message":"Session expired or invalid"}]`

**Re-authentication strategy**: On 401 from Salesforce, repeat the client credentials exchange, get a fresh token, and retry the failed request once.

**Connected App requirements**:
- Enable OAuth Settings with `api` scope (minimum for REST API access)
- Enable Client Credentials Flow (`isClientCredentialEnabled: true`, API 56.0+)
- Configure a "Run As" user — token inherits this user's permissions
- IP relaxation: "Relax IP restrictions" recommended for proxy hosts
- Available in Enterprise, Unlimited, Performance, and Developer editions (broadened in API 58.0+)

**REST API call format**:
```
POST https://<instance_url>/services/apexrest/<endpoint-path>
Authorization: Bearer <access_token>
Content-Type: application/json
```

---

## R4: 2GP Unlocked Packaging

### Decision: No-namespace unlocked package with `public virtual` extensibility

**Rationale**: Unlocked packages with no namespace allow subscribers to extend `public virtual` classes and implement `public` interfaces directly by name. No namespace prefix needed. This maximizes developer ergonomics while maintaining upgrade paths.

**Alternatives considered**: Managed package (rejected — namespace adds friction, code obfuscation unnecessary for this project, prevents subscriber debugging). Namespaced unlocked package (rejected — adds namespace prefix overhead without IP protection benefits).

### Key Findings

- In a no-namespace unlocked package, `public` is fully accessible to subscribers (equivalent to `global` in practice)
- `public virtual` classes can be extended; `public abstract` classes can be subclassed
- No IP protection — source code visible and editable (acceptable per spec assumptions)
- Unlocked packages can evolve their API freely between versions (no managed package restrictions on adding methods to virtual classes)
- **75% minimum test coverage** required for package promotion (`sf package version create --code-coverage`); target is 90%+

---

## R5: TypeScript Stdio Transport

### Decision: Newline-delimited JSON-RPC over stdin/stdout with no production npm dependencies

**Rationale**: MCP clients launch the proxy as a subprocess and communicate via stdio. The proxy reads JSON-RPC messages from stdin, forwards them to Salesforce via HTTP, and writes responses to stdout. Node.js built-in `readline` and `http`/`https` modules are sufficient.

**Alternatives considered**: Content-length framing (used by LSP; more complex, not required by MCP stdio transport). External HTTP libraries like `axios`/`node-fetch` (rejected — constitution mandates zero production dependencies).

### Key Findings

- Proxy is launched by MCP clients as: `npx salesforce-mcp-lib --instance-url <url> --client-id <id> --client-secret <secret> --endpoint <path>`
- stdin: receives JSON-RPC messages from MCP client (one per line)
- stdout: sends JSON-RPC responses back to MCP client (one per line)
- stderr: used for proxy diagnostic logging (configurable log level)
- Session management: proxy assigns `Mcp-Session-Id`, tracks protocol version and capabilities, manages lifecycle state
- Proxy is the only stateful component — Apex endpoint is fully stateless

---

## Resolution Summary

| Originally NEEDS CLARIFICATION | Resolution |
|---|---|
| N/A — no unknowns in Technical Context | All technical details were known from the spec, constitution, and existing codebase |

All research items resolved. No NEEDS CLARIFICATION items remain. Proceeding to Phase 1: Design & Contracts.
