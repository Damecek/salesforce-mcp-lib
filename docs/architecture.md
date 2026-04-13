# Architecture: Proxy and Direct Connection

## Overview

The Salesforce MCP Library has two components:

| Component | Role |
|-----------|------|
| **Apex MCP Server** (`force-app/`) | The MCP server. Implements JSON-RPC 2.0, MCP capability negotiation, and all tool/resource/prompt dispatch. Runs inside Salesforce with full platform security. |
| **TypeScript stdio proxy** (`packages/salesforce-mcp-lib/`) | A transport and authentication bridge. Converts stdio to HTTPS, manages OAuth 2.0 tokens, handles session lifecycle. Does not interpret MCP protocol messages. |

The Apex endpoint is the product. The proxy is a convenience layer that handles OAuth token lifecycle so the MCP host doesn't have to.

```
Path A (with proxy):   MCP Host <-> stdio <-> TS Proxy <-> HTTPS <-> Apex Endpoint
Path B (direct):       MCP Host <-> HTTPS + Bearer token <-> Apex Endpoint
```

Both paths deliver the same JSON-RPC 2.0 payloads to the same Apex `@RestResource` endpoint. The wire format is identical.

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
| **Automatic 401 re-authentication** | On `INVALID_SESSION_ID`, invalidates the cached token, re-authenticates, and retries the request once |
| **Secret redaction** | Tokens and credentials are never written to stderr logs |
| **Error translation** | HTTP errors are mapped to sanitized JSON-RPC error responses; raw Salesforce error bodies are logged to stderr, never exposed to the MCP client |

**What the proxy does NOT handle:**

- MCP protocol logic (capability negotiation, method routing)
- Tool, resource, or prompt dispatch
- Request validation beyond JSON-RPC framing
- Authorization (CRUD, FLS, sharing rules) -- that is enforced by the Salesforce platform

The proxy is a transparent JSON-RPC passthrough. All protocol logic lives in the Apex server.

---

## Connecting directly (without the proxy)

When the consumer already has Salesforce OAuth handling in place, you can skip the proxy entirely. This is typical for cloud platforms with native Salesforce connectors, automation services (n8n, Make), or custom agent orchestration layers that acquire a token, fire an agent with MCP, route the response back, and repeat. The Apex endpoint is stateless -- there is no session to maintain between calls, so every request is independent.

### What the consumer must handle

1. **Obtain an OAuth 2.0 access token** from Salesforce -- via client credentials, authorization code, JWT bearer, or any supported flow.
2. **POST JSON-RPC 2.0 requests** to `https://{instance}/services/apexrest/{your-endpoint}` with:
   - `Authorization: Bearer {access_token}`
   - `Content-Type: application/json`
   - Body: a single JSON-RPC 2.0 request object
3. **Handle token expiry**: re-authenticate on HTTP 401 responses containing `INVALID_SESSION_ID`.
4. **Parse the response**: the body is a JSON-RPC 2.0 response object.

### Example: direct HTTP request

```http
POST /services/apexrest/mcp/minimal HTTP/1.1
Host: your-org.my.salesforce.com
Authorization: Bearer 00D...
Content-Type: application/json

{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}
```

Response:

```http
HTTP/1.1 200 OK
Content-Type: application/json

{"jsonrpc":"2.0","id":1,"result":{"tools":[...]}}
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

The Apex endpoint accepts standard JSON-RPC 2.0 POST requests. All 11 MCP methods are implemented (`initialize`, `ping`, `tools/list`, `tools/call`, `resources/list`, `resources/read`, `resources/templates/list`, `resources/templates/call`, `prompts/list`, `prompts/get`, `notifications/initialized`).

See [mcp-wire-contract-audit-2025-11-25.md](mcp-wire-contract-audit-2025-11-25.md) for the complete protocol compliance matrix.

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
