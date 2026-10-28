# Architecture: Proxy and Direct Connection

## Overview

The Salesforce MCP Library has two components:

| Component | Role |
|-----------|------|
| **Apex MCP Server** (`force-app/`) | The MCP server. Implements JSON-RPC 2.0 framing, the two protocol eras (`2026-07-28` and `2025-11-25`), and tool, resource, template, prompt and completion dispatch. Runs inside Salesforce with full platform security. |
| **TypeScript stdio proxy** (`packages/salesforce-mcp-lib/`) | A transport and authentication bridge. Converts stdio to HTTPS, manages OAuth 2.0 tokens, and adds the MCP routing headers the modern HTTP transport requires. It reads only the JSON-RPC framing (`id`, `method`, protocol version, `params.name` or `params.uri`) and forwards each message body as-is. |

The Apex endpoint is the product. The proxy is a convenience layer that handles OAuth token lifecycle so the MCP host doesn't have to.

```
Path A (with proxy):   MCP Host <-> stdio <-> TS Proxy <-> HTTPS <-> Apex Endpoint
Path B (direct):       MCP Host <-> HTTPS + Bearer token <-> Apex Endpoint
```

Both paths deliver the same JSON-RPC 2.0 payloads to the same Apex `@RestResource` endpoint. A direct client must add the protocol headers itself (see [Wire format reference](#wire-format-reference)).

---

## Apex runtime pipeline

The 1.x generic JSON-RPC layer (`force-app/main/json-rpc`, batch support, `JsonRpc*` classes) is gone. One `McpRuntime` instance is created per HTTP request. It holds no static mutable state, runs no SOQL, DML or callouts, and processes the request in this order:

1. Method is `POST`, `Origin` is absent or allow-listed.
2. Body size is within the effective request limit (`min(maxRequestBytes, remaining heap / 8)`, default 256 KiB).
3. The raw text nests at most 32 levels (checked before the parser, strings and escapes aware). Then the body parses as JSON and passes a bounded walk (depth, node and collection limits).
4. Body is a single JSON-RPC object (batches are rejected). A notification gets 202 and stops here.
5. Era detection: `initialize` is legacy only when no version is named. Otherwise the version comes from `params._meta` and the `MCP-Protocol-Version` header and must be supported.
6. Modern only: required `_meta` fields, `Mcp-Method` and `Mcp-Name` headers match the body.
7. The method must exist in the era table and its capability must be advertised, otherwise `-32601` (HTTP 404 in the modern era).
8. Dispatch to the tool, resource, template, prompt or completion handler. `McpException` becomes a tool error result or `-32602`, anything else becomes `-32603` "Internal error".
9. The result is decorated for the era, walked to estimate its size (JSON-native values only: a `Set`, a `Map` with a non-`String` key or a custom object is refused first), serialized once, measured, and written with the real HTTP status. All method, header-value and enum comparisons are case-sensitive.

Class groups in `force-app/main/mcp/classes`: public API (`McpServer`, `McpTool`, `McpResource`, `McpResourceTemplate`, `McpPrompt`, results, `McpContent`, `McpSchema`, `McpRequest`, `McpException`), internals (`McpRuntime`, `McpWire`, `McpUriTemplate`, `McpProtocolException`) and tests. Internals are `public` only because Apex has no package-private scope. They are not a supported API.

The exact tables are in [mcp-wire-contract-2026-07-28.md](mcp-wire-contract-2026-07-28.md).

---

## What the proxy actually solves

Most MCP clients support both stdio and HTTP transports, so transport compatibility is not the primary concern. The proxy's main value is **OAuth token lifecycle management**.

Salesforce requires an OAuth 2.0 Bearer token on every API call. Tokens expire, sessions get invalidated, refresh tokens must be exchanged -- and all of this must happen transparently, without interrupting the MCP host. The proxy handles it: configure your credentials once, and it acquires, caches, refreshes, and re-acquires tokens automatically. Set once, run forever.

As a secondary benefit, the proxy also provides a stdio interface for clients that prefer it, and ensures tokens and credentials never leak into MCP client logs (automatic secret redaction on stderr).

---

## What the proxy handles

| Responsibility | Details |
|----------------|---------|
| **stdio transport** | Reads newline-delimited JSON-RPC from stdin, writes responses to stdout |
| **OAuth 2.0 client credentials** | Exchanges `client_id` + `client_secret` for an access token, caches it in memory |
| **OAuth 2.0 authorization code (PKCE)** | Per-user login flow with browser redirect, refresh token persistence in `~/.salesforce-mcp-lib/tokens/` |
| **Automatic 401 re-authentication** | On `INVALID_SESSION_ID`, re-authenticates (parallel 401s share one token request) and retries the request once |
| **Secret redaction** | Tokens and credentials are never written to stderr logs |
| **Error translation** | Remote failures that are not valid JSON-RPC become local `-32603` errors marked `data.source = "salesforce-mcp-lib-proxy"`; remote bodies, tokens and secrets are never logged or echoed |
| **MCP routing headers** | Adds `MCP-Protocol-Version`, `Mcp-Method` and `Mcp-Name` for modern requests |
| **Bounds** | Request timeout, concurrency limit, 64-request queue, 64 MiB byte budget, 8 MiB response cap, local cancellation, https-only URLs (loopback excepted) |

**What the proxy does NOT handle:**

- MCP protocol logic (capability negotiation, method routing). It does read `id`, `method`, the protocol version and `params.name`/`params.uri` to build headers.
- Tool, resource, or prompt dispatch
- Request validation beyond JSON-RPC framing and header-safe values
- SSE, subscriptions, tasks, MRTR: the Apex endpoint does not implement them
- Authorization (CRUD, FLS, sharing rules) -- that is enforced by the Salesforce platform

The proxy forwards message bodies unchanged (a remote body is only compacted to one line without touching number spelling). All protocol logic lives in the Apex server.

---

## Connecting directly (without the proxy)

When the consumer already has Salesforce OAuth handling in place, you can skip the proxy entirely. This is typical for cloud platforms with native Salesforce connectors, automation services (n8n, Make), or custom agent orchestration layers that acquire a token, fire an agent with MCP, route the response back, and repeat. The Apex endpoint is stateless -- there is no session to maintain between calls, so every request is independent.

### What the consumer must handle

1. **Obtain an OAuth 2.0 access token** from Salesforce -- via client credentials, authorization code, JWT bearer, or any supported flow.
2. **POST JSON-RPC 2.0 requests** to `https://{instance}/services/apexrest/{your-endpoint}` with:
   - `Authorization: Bearer {access_token}`
   - `Content-Type: application/json`
   - Modern era: `MCP-Protocol-Version: 2026-07-28`, `Mcp-Method: <method>`, and `Mcp-Name: <params.name or params.uri>` for `tools/call`, `prompts/get`, `resources/read`
   - Body: a single JSON-RPC 2.0 request object (no batches)
3. **Handle token expiry**: re-authenticate on HTTP 401 responses containing `INVALID_SESSION_ID`.
4. **Parse the response**: the body is a JSON-RPC 2.0 response object.

### Example: direct HTTP request

```http
POST /services/apexrest/mcp/minimal HTTP/1.1
Host: your-org.my.salesforce.com
Authorization: Bearer 00D...
Content-Type: application/json
MCP-Protocol-Version: 2026-07-28
Mcp-Method: tools/list

{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28","io.modelcontextprotocol/clientCapabilities":{}}}}
```

Response:

```http
HTTP/1.1 200 OK
Content-Type: application/json

{"jsonrpc":"2.0","id":1,"result":{"resultType":"complete","tools":[...],"ttlMs":0,"cacheScope":"private","_meta":{"io.modelcontextprotocol/serverInfo":{...}}}}
```

---

## Decision guide

| Your consumer... | Use the proxy? | What you handle |
|---|---|---|
| Has no Salesforce OAuth handling (Claude Desktop, Cursor, VS Code, most desktop clients) | **Yes** | Nothing extra -- proxy manages the full token lifecycle |
| Has its own Salesforce credential store / OAuth connector (n8n, Make, cloud agent platforms) | **No** | Token acquisition, refresh, session expiry, credential security |
| Custom orchestration layer (acquire token → fire agent with MCP → route response → repeat) | **No** | OAuth flow + per-request Bearer token; no session to maintain |

**If you remove the proxy, you are not removing complexity. You are taking ownership of it in another place** -- specifically, OAuth token acquisition, refresh logic, and session management move into your consumer.

---

## Wire format reference

The Apex endpoint accepts single JSON-RPC 2.0 POST requests in two eras: modern `2026-07-28` (stateless, `server/discover`, routing headers) and legacy `2025-11-25` (`initialize`, `ping`). Supported methods: `server/discover`, `initialize`, `ping`, `tools/list`, `tools/call`, `resources/list`, `resources/read`, `resources/templates/list`, `prompts/list`, `prompts/get`, `completion/complete`, plus notifications (202, no body). `resources/templates/call` from 1.x is removed.

See [mcp-wire-contract-2026-07-28.md](mcp-wire-contract-2026-07-28.md) for the full contract with sources. The older [audit](mcp-wire-contract-audit-2025-11-25.md) is superseded.

---

## Security considerations for direct connections

The same 4-layer security model applies regardless of whether you use the proxy or connect directly:

| Layer | Enforced by |
|-------|------------|
| OAuth 2.0 scopes | External Client App configuration |
| Profile permissions | Salesforce platform |
| Permission Sets | Salesforce platform |
| Sharing rules | Salesforce platform |

Without the proxy, the client is additionally responsible for:

- Secure credential storage (client secrets, refresh tokens)
- Token rotation and expiry handling
- Ensuring tokens and credentials are not logged or exposed to end users
