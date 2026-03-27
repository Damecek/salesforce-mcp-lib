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

## OAuth App Setup Is Manual

OAuth app setup is org-side. After installation, the user must complete authorization setup in Salesforce Setup and manually retrieve the generated credentials.

The agent must explain this explicitly:

- the user must enable or confirm client credentials flow in the target org
- the user must confirm the Run As user
- the user must retrieve the client ID and client secret manually
- those values are not discoverable from repo state, package metadata, or deploy output

## Salesforce Requirements

The target Salesforce app must have:

- OAuth client credentials flow enabled
- a configured Run As user
- scopes suitable for Apex REST / MCP access

## Required local exports

The bridge accepts credentials from CLI args or environment variables, but environment variables are the preferred default:

- `SF_CLIENT_ID`
- `SF_CLIENT_SECRET`
- optional `SF_SCOPE`

Canonical local setup:

```bash
export SF_CLIENT_ID='your-client-id'
export SF_CLIENT_SECRET='your-client-secret'
```

Do not claim these are auto-discoverable from the repository, package metadata, or org deploy output.

## Failure Triage

- Missing `SF_CLIENT_ID` or `SF_CLIENT_SECRET`:
  stop and ask the user to finish the manual export step before debugging transport behavior.
- HTTP 400:
  Salesforce rejected the client credentials request. Check OAuth settings, scopes, and whether the flow is enabled.
- HTTP 401:
  check the client secret, connected app policy, and Run As user configuration.
- Missing `access_token` in token response:
  treat this as an auth configuration failure, not as an MCP transport bug.
