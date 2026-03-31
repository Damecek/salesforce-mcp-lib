# Minimal MCP Example

A single-tool MCP server that echoes input back to the caller. This is the simplest possible example of an Apex MCP endpoint.

## What it does

- Registers one tool (`echo`) that returns the provided message unchanged
- Exposes a single REST endpoint at `/services/apexrest/mcp/minimal`

## Deploy

```bash
sf project deploy start \
  --source-dir examples/minimal/force-app \
  --target-org <org>
```

## Test

```bash
npx salesforce-mcp-lib \
  --instance-url <url> \
  --client-id <id> \
  --client-secret <secret> \
  --endpoint /services/apexrest/mcp/minimal
```
