# Authorization

## Model

The local bridge authenticates to Salesforce, not the agent.

Flow:

1. the agent starts the local `salesforce-mcp-lib` process
2. the bridge derives the token endpoint from the Salesforce origin
3. the bridge requests an access token with `grant_type=client_credentials`
4. the bridge sends `Authorization: Bearer <token>` to the Apex REST MCP endpoint
5. the agent talks only to the local bridge over `stdio`

Token endpoint shape:

```text
https://<host>/services/oauth2/token
```

## Salesforce Requirements

The target Salesforce app must have:

- OAuth client credentials flow enabled
- a configured Run As user
- scopes suitable for Apex REST / MCP access

The bridge accepts credentials from CLI args or environment variables:

- `SF_CLIENT_ID`
- `SF_CLIENT_SECRET`
- optional `SF_SCOPE`

## Manual Operator Step

`SF_CLIENT_ID` and `SF_CLIENT_SECRET` are manual local prerequisites.

Do not try to infer them from:

- repo files
- scratch-org deploy output
- package metadata
- existing smoke scripts

If either secret is missing, stop and tell the operator to export them locally:

```bash
export SF_CLIENT_ID='your-consumer-key'
export SF_CLIENT_SECRET='your-consumer-secret'
```

## Common Failure Modes

- HTTP 400:
  Salesforce rejected the client credentials request. Check OAuth settings, scopes, and whether the flow is enabled.
- HTTP 401:
  check the client secret, connected app policy, and Run As user configuration.
- Missing `access_token` in token response:
  treat this as an auth configuration failure, not as an MCP transport bug.

## Bridge Command

Direct bridge invocation:

```bash
npx salesforce-mcp-lib \
  --url "https://<host>/services/apexrest/mcp" \
  --client-id "$SF_CLIENT_ID" \
  --client-secret "$SF_CLIENT_SECRET"
```

Environment-variable variant:

```bash
SF_CLIENT_ID=... \
SF_CLIENT_SECRET=... \
npx salesforce-mcp-lib --url "https://<host>/services/apexrest/mcp"
```
