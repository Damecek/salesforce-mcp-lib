# Full E2E MCP Example

Demonstrates all three MCP capability types: tool, resource, and prompt.

## Deploy

```bash
sf project deploy start --source-dir examples/e2e-http-endpoint/force-app --target-org <org>
```

## Test with MCP Inspector

```bash
npx @modelcontextprotocol/inspector \
  npx salesforce-mcp-lib \
    --instance-url https://your-org.my.salesforce.com \
    --client-id YOUR_KEY \
    --client-secret YOUR_SECRET \
    --endpoint /services/apexrest/mcp/e2e
```

## Capabilities

- **Tool**: `query_accounts` -- search Account records by name
- **Resource**: `salesforce://org/info` -- org metadata
- **Prompt**: `summarize_record` -- generate a record summary prompt
