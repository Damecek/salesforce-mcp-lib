# Wiring

## Separate The Layers

Keep these responsibilities distinct:

- Apex runtime:
  owns MCP definitions, typed handlers, and the remote Apex REST endpoint
- local bridge:
  owns OAuth client credentials and local `stdio` exposure for the agent

Do not describe the bridge as the Salesforce server implementation.
It is the local edge process in front of the Salesforce endpoint.

## Apex Server Authoring

Use the examples in this repo as the baseline:

- minimal server shape:
  `examples/minimal/MinimalMcpExample.apex`
- full HTTP endpoint shape:
  `examples/e2e-http-endpoint/ExampleMcpEndpoint.apex`
- matching factory example:
  `examples/e2e-http-endpoint/ExampleMcpServerFactory.apex`

Typical flow:

1. create an `McpServer`
2. register typed tools, resources, templates, and prompts as needed
3. expose an Apex REST endpoint with `@RestResource`
4. delegate HTTP request handling to the MCP transport layer

## Endpoint Shapes

Current endpoint shapes used in this repo include:

- `/services/apexrest/mcp`
- `/services/apexrest/mcp/opportunity/`
- `/services/apexrest/opportunity/mcp`

When operating on the scratch harness in this repo, prefer:

```bash
./scripts/harness-url.sh
```

For non-default endpoints, override `MCP_PATH` instead of constructing the full URL manually:

```bash
MCP_PATH=/services/apexrest/mcp/opportunity/ ./scripts/harness-url.sh
```

## URL Requirements

The bridge expects a full HTTPS Apex REST endpoint URL.

Examples:

```text
https://<host>/services/apexrest/mcp
https://<host>/services/apexrest/mcp/opportunity/
https://<host>/services/apexrest/opportunity/mcp
```

## When Working Outside This Repo

If the user is building a Salesforce MCP server in another repo:

- still follow the same architectural split
- still derive the OAuth token endpoint from the Salesforce origin
- reuse this repo's examples as the canonical pattern for typed Apex MCP contracts and Apex REST transport wiring
