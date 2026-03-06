# E2E HTTP Endpoint Example

This example wires a full Apex REST endpoint using the library transport adapter.

## What it demonstrates
- Apex REST endpoint (`@RestResource`) delegating to `McpHttpTransport`.
- Server registration for list endpoints and call/read/template handlers.
- MVP demo capabilities kept in examples only:
  - Tool: `math.sum`
  - Resource: `mcp://secret/one`
  - Template: `secret-sum`

## Example Apex files
- [`ExampleMcpEndpoint.apex`](./ExampleMcpEndpoint.apex)
- [`ExampleMcpServerFactory.apex`](./ExampleMcpServerFactory.apex)

## Request examples
Endpoint URL (no namespace):
`/services/apexrest/mcp-example`

### Initialize
```json
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}
```

### List tools
```json
{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}
```

### Call sum tool
```json
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"math.sum","arguments":{"a":2,"b":5}}}
```

### Read resource
```json
{"jsonrpc":"2.0","id":4,"method":"resources/read","params":{"uri":"mcp://secret/one"}}
```

### Call resource template
```json
{"jsonrpc":"2.0","id":5,"method":"resources/templates/call","params":{"name":"secret-sum","arguments":{"value":9}}}
```
