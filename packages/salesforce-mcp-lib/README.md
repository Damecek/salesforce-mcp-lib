# salesforce-mcp-lib

[![npm](https://img.shields.io/npm/v/salesforce-mcp-lib)](https://www.npmjs.com/package/salesforce-mcp-lib)
[![license](https://img.shields.io/npm/l/salesforce-mcp-lib)](https://github.com/Damecek/salesforce-mcp-lib/blob/main/LICENSE)

TypeScript proxy that bridges MCP clients to a Salesforce Apex MCP endpoint. Its main value is OAuth 2.0 token lifecycle management -- configure once, run forever. Optional when the consumer already handles Salesforce OAuth tokens.

**Zero npm production dependencies.** Node.js >= 20.

![Architecture](https://raw.githubusercontent.com/Damecek/salesforce-mcp-lib/main/docs/images/architecture.jpg)

## What it does

- Reads JSON-RPC 2.0 messages from **stdin**, forwards them over HTTPS to your Salesforce org
- Authenticates via OAuth 2.0 **client_credentials** flow, caches the token, and re-authenticates automatically on 401
- Writes JSON-RPC responses to **stdout**, logs to **stderr** with automatic secret redaction

## When to use this package

**Use it when** your MCP host does not manage Salesforce OAuth tokens on its own. This covers most desktop clients (Claude Desktop, Cursor, VS Code extensions) and any integration without a built-in Salesforce credential store. The proxy handles the full token lifecycle -- acquire, cache, refresh, re-authenticate on 401 -- so you configure credentials once and it runs forever.

**Skip it when** the consumer already handles Salesforce OAuth. Cloud platforms with native Salesforce connectors, automation services (n8n, Make), or custom agent orchestration layers that acquire a token, fire an agent with MCP, route the response, and repeat. The Apex endpoint is stateless -- no session to maintain between calls.

What the proxy handles for you: OAuth 2.0 flows (client credentials or authorization code with PKCE), token caching, automatic 401 re-authentication, secret redaction in logs.

What you take ownership of without it: token acquisition, token refresh, session expiry handling, and credential security.

See [Architecture: Proxy and Direct Connection](https://github.com/Damecek/salesforce-mcp-lib/blob/main/docs/architecture.md) for the full rationale.

## Usage

### With `npx` (no install needed)

```bash
npx salesforce-mcp-lib \
  --instance-url https://your-org.my.salesforce.com \
  --client-id YOUR_CLIENT_ID \
  --client-secret YOUR_CLIENT_SECRET \
  --endpoint /services/apexrest/mcp/minimal
```

### In an MCP client config

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

### Environment variables

All options can be set via environment variables instead of CLI flags:

| CLI flag | Env variable | Required |
|----------|-------------|----------|
| `--instance-url` | `SF_INSTANCE_URL` | Yes |
| `--client-id` | `SF_CLIENT_ID` | Yes |
| `--client-secret` | `SF_CLIENT_SECRET` | Yes |
| `--endpoint` | `SF_ENDPOINT` | Yes |
| `--log-level` | `SF_LOG_LEVEL` | No (default: `info`) |

## Prerequisites

This proxy connects to an Apex MCP endpoint running in your Salesforce org. You need:

1. **Salesforce MCP Library** installed in your org ([install instructions](https://github.com/Damecek/salesforce-mcp-lib#1-install-the-apex-framework))
2. At least one `@RestResource` endpoint with registered MCP capabilities
3. An **External Client App** with OAuth 2.0 Client Credentials flow enabled

See the [main README](https://github.com/Damecek/salesforce-mcp-lib) for the ECA-first quick-start guide.

## How it works

```
MCP Client (Claude, ChatGPT, ...)
    ↕ stdio · JSON-RPC 2.0
salesforce-mcp-lib (this package)
    ↕ HTTPS POST · Bearer token
Salesforce Apex @RestResource endpoint
```

The proxy is a transparent JSON-RPC passthrough — it doesn't interpret MCP methods. All protocol logic lives in the Apex server.

The Apex `@RestResource` endpoint is the actual MCP server. This package provides OAuth token lifecycle management (acquire, cache, refresh, re-authenticate) and stdio-to-HTTPS transport. It does not interpret or modify MCP protocol messages.

## License

[MIT](https://github.com/Damecek/salesforce-mcp-lib/blob/main/LICENSE)
