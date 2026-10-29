# salesforce-mcp-lib

[![npm](https://img.shields.io/npm/v/salesforce-mcp-lib)](https://www.npmjs.com/package/salesforce-mcp-lib)
[![license](https://img.shields.io/npm/l/salesforce-mcp-lib)](https://github.com/Damecek/salesforce-mcp-lib/blob/main/LICENSE)

TypeScript proxy that bridges MCP clients to a Salesforce Apex MCP endpoint. Its main value is OAuth 2.0 token lifecycle management -- configure once, run forever. Optional when the consumer already handles Salesforce OAuth tokens.

**Zero npm production dependencies.** Node.js >= 20.

> **Version 2.0.0 is published on npm.** Run it with `npx salesforce-mcp-lib@2.0.0`. 1.x releases do not
> work with the 2.x Apex framework.
> The Salesforce package 2.0.0.1 is released. Install the Apex side with
> `https://login.salesforce.com/packaging/installPackage.apexp?p0=04tdL000000qXzBQAU`
> or see the [main README](https://github.com/Damecek/salesforce-mcp-lib#1-install-the-apex-framework).
> Raw JSON schemas passed to `inputSchema(Map)` are not validated against arguments. That is the developer's
> responsibility.

![Architecture](https://raw.githubusercontent.com/Damecek/salesforce-mcp-lib/main/docs/images/architecture.jpg)

## What it does

- Reads JSON-RPC 2.0 messages from **stdin**, forwards them over HTTPS to your Salesforce org
- Adds the MCP routing headers (`MCP-Protocol-Version`, `Mcp-Method`, `Mcp-Name`) that the modern `2026-07-28` HTTP transport requires, and serves both `2026-07-28` and `2025-11-25` clients
- Authenticates via OAuth 2.0 (**client credentials** or **per-user authorization code with PKCE**), caches tokens, and refreshes automatically
- Writes JSON-RPC responses to **stdout**, logs to **stderr** with automatic secret redaction

## Supported protocol versions

The proxy forwards both eras to the Apex endpoint: modern `2026-07-28` (stateless, `server/discover`) and legacy
`2025-11-25` (`initialize`, `ping`). It does not implement SSE, subscriptions, tasks, MRTR (elicitation, sampling,
roots), progress or logging, because the Apex endpoint cannot serve them: one Apex REST request is one synchronous
call with governor limits. JSON-RPC batches are rejected with `-32600`. Per-tool rate limiting is not implemented
on the server side, so this library does not claim full MCP compliance. See the full
[feature matrix](https://github.com/Damecek/salesforce-mcp-lib#feature-matrix).

## When to use this package

**Use it when** your MCP host does not manage Salesforce OAuth tokens on its own. This covers most desktop clients (Claude Desktop, Cursor, VS Code extensions) and any integration without a built-in Salesforce credential store. The proxy handles the full token lifecycle -- acquire, cache, refresh, re-authenticate on 401 -- so you configure credentials once and it runs forever.

**Skip it when** the consumer already handles Salesforce OAuth. Cloud platforms with native Salesforce connectors, automation services (n8n, Make), or custom agent orchestration layers that acquire a token, fire an agent with MCP, route the response, and repeat. The Apex endpoint is stateless -- no session to maintain between calls.

What the proxy handles for you: OAuth 2.0 flows (client credentials or authorization code with PKCE), token caching, automatic 401 re-authentication, secret redaction in logs.

What you take ownership of without it: token acquisition, token refresh, session expiry handling, and credential security.

See [Architecture: Proxy and Direct Connection](https://github.com/Damecek/salesforce-mcp-lib/blob/main/docs/architecture.md) for the full rationale.

## Usage

The auth mode is auto-detected: `--client-secret` present → client credentials flow; absent → per-user auth (authorization code + PKCE).

### Per-User Auth (recommended)

**Step 1, one-time login:**

```bash
npx salesforce-mcp-lib login \
  --instance-url https://your-org.my.salesforce.com \
  --client-id YOUR_CLIENT_ID
```

A browser window opens, you log in with your Salesforce credentials and grant access. Tokens are stored locally and persist across restarts via automatic refresh.

**Step 2, MCP client config** (no `--client-secret`):

```json
{
  "mcpServers": {
    "salesforce": {
      "command": "npx",
      "args": [
        "-y", "salesforce-mcp-lib",
        "--instance-url", "https://your-org.my.salesforce.com",
        "--client-id", "YOUR_CLIENT_ID",
        "--endpoint", "/services/apexrest/mcp/minimal"
      ]
    }
  }
}
```

See the [Per-User Auth Setup Guide](https://github.com/Damecek/salesforce-mcp-lib/blob/main/specs/003-per-user-auth/quickstart.md) for External Client App configuration, headless environments, and troubleshooting.

### Client Credentials (service account)

```json
{
  "mcpServers": {
    "salesforce": {
      "command": "npx",
      "args": [
        "-y", "salesforce-mcp-lib",
        "--instance-url", "https://your-org.my.salesforce.com",
        "--client-id", "YOUR_CLIENT_ID",
        "--client-secret", "YOUR_CLIENT_SECRET",
        "--endpoint", "/services/apexrest/mcp/minimal"
      ]
    }
  }
}
```

### With `npx` (no install needed)

```bash
npx salesforce-mcp-lib \
  --instance-url https://your-org.my.salesforce.com \
  --client-id YOUR_CLIENT_ID \
  --client-secret YOUR_CLIENT_SECRET \
  --endpoint /services/apexrest/mcp/minimal
```

## CLI reference

### MCP server mode

```
salesforce-mcp-lib [options]
```

| CLI flag | Env variable | Required | Description |
|----------|-------------|----------|-------------|
| `--instance-url` | `SF_INSTANCE_URL` | Yes | Salesforce org URL |
| `--client-id` | `SF_CLIENT_ID` | Yes | External Client App consumer key |
| `--client-secret` | `SF_CLIENT_SECRET` | No* | External Client App consumer secret |
| `--endpoint` | `SF_ENDPOINT` | Yes | Apex REST endpoint path |
| `--callback-port` | `SF_CALLBACK_PORT` | No | OAuth callback port (default: `13338`) |
| `--log-level` | `SF_LOG_LEVEL` | No | `debug` / `info` / `warn` / `error` (default: `info`) |
| `--request-timeout-ms` | `SF_REQUEST_TIMEOUT_MS` | No | Deadline per forwarded request, covering authentication, retry and response (1000 to 600000, default: `120000`) |
| `--max-concurrency` | `SF_MAX_CONCURRENCY` | No | Concurrent requests to Salesforce (1 to 25, default: `4`) |

`--instance-url` must be `https`. Plain `http` is accepted only for `localhost`, `[::1]` and `127.x.x.x` (tests). `--endpoint` must be a path starting with a single `/`.

\* When `--client-secret` is provided → client credentials flow. When omitted → per-user auth (requires prior `login`).

### Login subcommand

```
salesforce-mcp-lib login [options]
```

| CLI flag | Env variable | Required | Description |
|----------|-------------|----------|-------------|
| `--instance-url` | `SF_INSTANCE_URL` | Yes | Salesforce org URL |
| `--client-id` | `SF_CLIENT_ID` | Yes | External Client App consumer key |
| `--headless` | `SF_HEADLESS` | No | Print auth URL instead of opening browser |
| `--callback-port` | `SF_CALLBACK_PORT` | No | OAuth callback port (default: `13338`) |
| `--log-level` | `SF_LOG_LEVEL` | No | Log level (default: `info`) |

## Behaviour and limits

- **Concurrency and queue.** Up to `--max-concurrency` requests run at once, 64 more may wait, then a request gets a local `-32603` error. Queued plus in-flight input is capped at **64 MiB** in total, one input line at 6 MiB.
- **Responses.** A remote body over 8 MiB is aborted with a local error. A remote JSON-RPC body is passed through with only inter-token whitespace removed, so large integers and decimals keep their exact digits (**lossless numeric pass-through**).
- **Timeouts.** `--request-timeout-ms` is one deadline over authentication, a retry after 401, and the response. OAuth calls have a separate 30 s total deadline.
- **Notifications and cancellation.** `notifications/cancelled` is handled in the proxy. It removes a queued request or aborts an in-flight one and drops its response. Work that Apex already started still completes. The proxy never forwards it. Other notifications are forwarded and never answered. Client responses to server requests are dropped (the server sends none).
- **Errors.** A failure that is not a JSON-RPC answer (Salesforce error array, HTML, network error) becomes a local `-32603` error with `data.source = "salesforce-mcp-lib-proxy"`. Remote bodies, tokens and secrets never reach logs or error messages.
- **Shutdown.** When stdin ends, the proxy answers queued and in-flight requests, then exits 0.
- **Dependencies.** None at runtime. Node.js 20 or newer.

## Prerequisites

This proxy connects to an Apex MCP endpoint running in your Salesforce org. You need:

1. **Salesforce MCP Library 2.x** installed in your org (source install for now, see the [install instructions](https://github.com/Damecek/salesforce-mcp-lib#1-install-the-apex-framework)). The proxy 2.0.0 needs the 2.x Apex framework, because it sends the protocol headers the 2.x endpoint validates.
2. At least one `@RestResource` endpoint with registered MCP capabilities
3. An **External Client App**: either Client Credentials flow (service account) or Authorization Code + PKCE flow (per-user auth)

See the [main README](https://github.com/Damecek/salesforce-mcp-lib) for the ECA quick-start guide (both auth modes).

## How it works

```
MCP Client (Claude, ChatGPT, ...)
    ↕ stdio · JSON-RPC 2.0
salesforce-mcp-lib (this package)
    ↕ HTTPS POST · Bearer token
Salesforce Apex @RestResource endpoint
```

The proxy does not interpret MCP methods. It reads only the JSON-RPC framing (`id`, `method`, protocol version, `params.name` or `params.uri`) to build headers and to match responses, and forwards the message body unchanged. All protocol logic lives in the Apex server.

The Apex `@RestResource` endpoint is the actual MCP server. This package provides OAuth token lifecycle management (acquire, cache, refresh, re-authenticate) and stdio-to-HTTPS transport.

### HTTP authentication discovery

The Apex endpoint is JSON-only and does not publish OAuth protected-resource metadata. Salesforce itself answers an unauthenticated request with its own 401. A client that wants to discover OAuth endpoints from the MCP server therefore cannot do so. Use this proxy, or give your client a Bearer token from an External Client App.

## License

[MIT](https://github.com/Damecek/salesforce-mcp-lib/blob/main/LICENSE)
