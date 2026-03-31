# Minimal MCP Example

A bare-minimum example: one tool, one endpoint.

## Deploy

```bash
sf project deploy start --source-dir examples/minimal/force-app --target-org <org>
```

## Test

```bash
npx salesforce-mcp-lib \
  --instance-url https://your-org.my.salesforce.com \
  --client-id YOUR_KEY \
  --client-secret YOUR_SECRET \
  --endpoint /services/apexrest/mcp/minimal
```
