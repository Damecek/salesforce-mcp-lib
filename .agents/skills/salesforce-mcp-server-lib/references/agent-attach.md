# Agent Attach

## Goal

Attach the Salesforce MCP server to a local MCP-capable agent through the published `npx` bridge command.

## Required command

The agent must not connect directly to Salesforce. It should connect through a local `stdio` process started with:

```bash
npx salesforce-mcp-lib --url "https://<host>/services/apexrest/mcp"
```

Supported dedicated flags:

- `--url`
- `--client-id`
- `--client-secret`
- optional `--scope`

Credentials should be passed through environment variables by default:

```bash
export SF_CLIENT_ID='your-client-id'
export SF_CLIENT_SECRET='your-client-secret'

npx salesforce-mcp-lib --url "https://<host>/services/apexrest/mcp"
```

Inline-flag variant when the client requires explicit arguments:

```bash
npx salesforce-mcp-lib \
  --url "https://<host>/services/apexrest/mcp" \
  --client-id "$SF_CLIENT_ID" \
  --client-secret "$SF_CLIENT_SECRET" \
  --scope "$SF_SCOPE"
```

## Codex example

Concrete local registration:

```bash
codex mcp add salesforce-org \
  --env "SF_CLIENT_ID=${SF_CLIENT_ID}" \
  --env "SF_CLIENT_SECRET=${SF_CLIENT_SECRET}" \
  -- npx salesforce-mcp-lib --url "https://<host>/services/apexrest/mcp"
```

This gives Codex a command-based MCP server that proxies to Salesforce through the local bridge.

## Other clients

For Cursor, Claude Desktop, or any other MCP-capable client:

- register a local command-based MCP server
- use `npx salesforce-mcp-lib --url "<full-url>"` as the command
- pass `SF_CLIENT_ID` and `SF_CLIENT_SECRET` in the MCP server environment by default
- use `--client-id`, `--client-secret`, and optional `--scope` only when the client requires inline flags

Do not invent client-specific UI steps unless the client is explicitly known.
