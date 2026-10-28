# Minimal MCP Example

A bare-minimum example: one tool (`echo`), one endpoint (`/services/apexrest/mcp/minimal`), one test.
It uses the 2.0.0 API: `new McpServer(name, version).tool(...).handle(...)` and `McpTool` with an `McpSchema` input.

## Deploy

The example needs the framework classes in the org (source install from `force-app/`, see the root README):

```bash
sf project deploy start --source-dir force-app --source-dir examples/minimal/force-app --target-org <org>
```

## Test

Apex: `sf apex run test --class-names MinimalMcpEndpointTest --target-org <org> --wait 10`.

Through the proxy (2.0.0 is unreleased on npm, so run it from a checkout after `npm ci && npm run build` in
`packages/salesforce-mcp-lib`):

```bash
node packages/salesforce-mcp-lib/dist/index.js \
  --instance-url https://your-org.my.salesforce.com \
  --client-id YOUR_KEY \
  --client-secret YOUR_SECRET \
  --endpoint /services/apexrest/mcp/minimal
```

Once published, `npx salesforce-mcp-lib` takes the same flags.
