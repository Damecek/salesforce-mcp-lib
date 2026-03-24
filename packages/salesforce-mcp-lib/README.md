# salesforce-mcp-lib

Local `stdio` MCP bridge for Salesforce Apex REST MCP endpoints authenticated with OAuth 2.0 client credentials.

## Usage

```bash
npx salesforce-mcp-lib \
  --url https://carvago--devas.sandbox.my.salesforce.com/services/apexrest/mcp/opportunity/ \
  --client-id "$SF_CLIENT_ID" \
  --client-secret "$SF_CLIENT_SECRET"
```

Credentials can also come from environment variables:

- `SF_CLIENT_ID`
- `SF_CLIENT_SECRET`
- `SF_SCOPE` optional

## Requirements

- Node.js 20+
- A Salesforce External Client App or Connected App with:
  - Client Credentials Flow enabled
  - a configured Run As user
  - scopes suitable for Apex REST/MCP access

Supported endpoint examples:

```bash
https://<host>/services/apexrest/mcp
https://<host>/services/apexrest/mcp/opportunity/
```

## URL Rules

`--url` must be a full HTTPS Salesforce Apex REST MCP endpoint, for example:

- `https://<host>/services/apexrest/mcp`
- `https://<host>/services/apexrest/mcp/opportunity/`
- `https://<host>/services/apexrest/opportunity/mcp`

The OAuth token endpoint is derived from the same origin as:

- `https://<host>/services/oauth2/token`
