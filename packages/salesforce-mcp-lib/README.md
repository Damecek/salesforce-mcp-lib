# salesforce-mcp-lib

[![npm](https://img.shields.io/npm/v/salesforce-mcp-lib)](https://www.npmjs.com/package/salesforce-mcp-lib)
[![license](https://img.shields.io/npm/l/salesforce-mcp-lib)](https://github.com/Damecek/salesforce-mcp-lib/blob/main/LICENSE)

TypeScript stdio proxy that bridges any MCP client (Claude, ChatGPT, etc.) to a Salesforce Apex MCP endpoint via OAuth 2.0.

**Zero npm production dependencies.** Node.js >= 20.

![Architecture](https://raw.githubusercontent.com/Damecek/salesforce-mcp-lib/main/docs/images/architecture.jpg)

## What it does

- Reads JSON-RPC 2.0 messages from **stdin**, forwards them over HTTPS to your Salesforce org
- Authenticates via OAuth 2.0 **client_credentials** flow, caches the token, and re-authenticates automatically on 401
- Writes JSON-RPC responses to **stdout**, logs to **stderr** with automatic secret redaction

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

## License

[MIT](https://github.com/Damecek/salesforce-mcp-lib/blob/main/LICENSE)
