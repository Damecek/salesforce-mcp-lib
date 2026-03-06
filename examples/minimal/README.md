# Minimal MCP Server Example

This example shows the smallest consumer-side setup for the packaged library.

## What it demonstrates
- Create `McpServer`.
- Register one tool, one resource, one resource template.
- Execute JSON-RPC payload with `server.execute(...)`.

## Notes
- This code is example-only and not part of package runtime defaults.
- MVP demo capabilities here:
  - Tool: sum two integers.
  - Resource: secret integer = `1`.
  - Resource template: sum input with secret.

## Example Apex
See [`MinimalMcpExample.apex`](./MinimalMcpExample.apex).
