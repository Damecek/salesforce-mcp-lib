# MCP Inspector Harness

This harness is designed for `@modelcontextprotocol/inspector` CLI mode against the deployed Salesforce Apex REST endpoint.

Context7 source used for this setup:
- library id: `/modelcontextprotocol/inspector`
- relevant guidance: remote HTTP CLI mode, `--transport http`, `--header`, JSON-valued `--tool-arg`, and config-file support

Observed package behavior during implementation:
- the published Inspector package includes a local proxy server that reliably forwards authenticated `streamable-http` requests
- the wrapped `--cli` entrypoint in the current package version does not successfully execute authenticated remote HTTP calls end-to-end for this Salesforce use case
- the automated smoke script therefore uses the Inspector proxy server as the executable validation path

## Expected endpoint
`https://<my-domain>.my.salesforce.com/services/apexrest/mcp`

## Commands
- `npm run harness:url`
- `npm run harness:token`
- `npm run harness:inspect:smoke`
- `npm run harness:proxy:smoke`

## Smoke strategy
`harness:inspect:smoke` starts the Inspector proxy locally, opens a `streamable-http` session to the Salesforce endpoint, forwards `Authorization: Bearer <sf token>`, and then executes MCP JSON-RPC requests through the proxy session.

`harness:proxy:smoke` uses the publishable `salesforce-mcp-lib` stdio bridge instead. It expects `SF_CLIENT_ID` and `SF_CLIENT_SECRET` to be configured for a Connected App that supports the Salesforce client credentials flow.

## Covered MCP methods
- `initialize`
- `tools/list`
- `tools/call`
- `resources/list`
- `resources/read`
- `resources/templates/list`
- `resources/templates/call`
- `prompts/list`
- `prompts/get`

## Nested object tool
The smoke suite calls `math.profile_sum` with a nested `profile={...}` JSON argument to validate nested Apex DTO deserialization and schema publication through `tools/list`.
