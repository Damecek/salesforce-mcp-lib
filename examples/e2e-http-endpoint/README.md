# Full E2E MCP Example

Demonstrates every capability type of the 2.0.0 API: tool, resource, resource template and prompt. All classes are
`with sharing`, and the queries use `WITH USER_MODE`, so the calling user's object and field permissions apply.

## Deploy

The example needs the framework classes in the org (source install from `force-app/`, see the root README):

```bash
sf project deploy start --source-dir force-app --source-dir examples/e2e-http-endpoint/force-app --target-org <org>
```

## Test

Apex: `sf apex run test --class-names E2eHttpEndpointTest --target-org <org> --wait 10`.

With MCP Inspector, through the proxy built from this checkout (`run-inspector.sh` builds and links it):

```bash
./examples/e2e-http-endpoint/run-inspector.sh \
  --instance-url https://your-org.my.salesforce.com \
  --client-id YOUR_KEY \
  --client-secret YOUR_SECRET
```

## Capabilities

- **Tool**: `query_accounts` searches Account records by name and returns `structuredContent` (output schema included)
- **Resource**: `salesforce://org/info` returns org metadata, cached by clients for 60 seconds
- **Resource template**: `salesforce://account/{id}` reads one Account (RFC 6570 level 1)
- **Prompt**: `summarize_record` returns a user message that asks for a record summary
