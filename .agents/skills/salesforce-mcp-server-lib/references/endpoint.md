# Endpoint

## Goal

Confirm the exact full HTTPS Apex REST MCP endpoint URL before implementation or bridge setup.

## Required shape

The bridge requires a full Salesforce Apex REST URL, not only a host and not only a path.

Valid examples:

```text
https://<host>/services/apexrest/mcp
https://<host>/services/apexrest/mcp/opportunity/
https://<host>/services/apexrest/opportunity/mcp
```

Reject vague inputs such as:

- `https://<host>`
- `/services/apexrest/mcp`
- `my sandbox URL`

## Confirmation rule

Before implementation, explicitly confirm:

- the Salesforce host
- the Apex REST path
- the final combined HTTPS URL

If the user has not yet created the endpoint, the agent must plan or implement the Apex REST class and only then present the final URL.

## Wiring rule

Keep the responsibilities separate:

- Apex owns the remote MCP endpoint
- `salesforce-mcp-lib` owns the local `stdio` bridge

When using this repository as the reference implementation, the canonical Apex REST pattern is:

```apex
@RestResource(urlMapping='/mcp/*')
global inherited sharing class MyEndpoint {
    @HttpPost
    global static void handlePost() {
        McpHttpTransport.handlePost(MyServerFactory.build());
    }
}
```
