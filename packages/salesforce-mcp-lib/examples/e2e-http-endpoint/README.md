# End-to-End HTTP Endpoint Example

A full MCP server demonstrating tools, resources, and prompts over a single Apex REST endpoint.

## What it does

- **Tool** (`query_accounts`): Searches Account records by name using SOQL
- **Resource** (`salesforce://org/info`): Returns basic org information (name, type, sandbox status)
- **Prompt** (`summarize_record`): Generates a prompt to summarize any Salesforce record by object name and ID

All capabilities are registered on a single endpoint at `/services/apexrest/mcp/e2e`.

## Deploy

```bash
sf project deploy start \
  --source-dir examples/e2e-http-endpoint/force-app \
  --target-org <org>
```

## Test

```bash
npx salesforce-mcp-lib \
  --instance-url <url> \
  --client-id <id> \
  --client-secret <secret> \
  --endpoint /services/apexrest/mcp/e2e
```
