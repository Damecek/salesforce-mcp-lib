# MCP JSON-RPC Wire Contract

**Feature**: 001-apex-mcp-server | **Date**: 2026-03-30
**Protocol**: JSON-RPC 2.0 over MCP 2025-11-25

This contract defines the exact JSON-RPC message formats exchanged between MCP clients and the Salesforce MCP server (via the TypeScript proxy). All messages conform to JSON-RPC 2.0 and MCP 2025-11-25.

---

## Transport Layer

### Client-facing (MCP client ↔ Proxy)

- **Transport**: stdio (stdin/stdout)
- **Framing**: newline-delimited JSON (one JSON-RPC message per line)
- **Direction**: bidirectional — client sends requests/notifications via stdin; proxy sends responses via stdout
- **Logging**: proxy diagnostic output goes to stderr only

### Server-facing (Proxy ↔ Salesforce)

- **Transport**: HTTPS POST
- **Endpoint**: `POST https://<instance_url>/services/apexrest/<subscriber-endpoint-path>`
- **Authentication**: `Authorization: Bearer <access_token>` (OAuth 2.0 client credentials)
- **Content-Type**: `application/json`
- **Session**: proxy manages `Mcp-Session-Id`; Apex endpoint is stateless

---

## Lifecycle Methods

### `initialize`

**Direction**: client → server

**Request**:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "2025-11-25",
    "capabilities": {},
    "clientInfo": {
      "name": "ExampleClient",
      "version": "1.0.0"
    }
  }
}
```

| Param | Type | Required | Description |
|---|---|---|---|
| protocolVersion | string | Yes | MCP protocol version |
| capabilities | object | Yes | Client capabilities (may be empty) |
| clientInfo | object | Yes | Client name (required) and version (optional) |

**Response** (success):
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "protocolVersion": "2025-11-25",
    "capabilities": {
      "tools": {},
      "resources": {},
      "prompts": {}
    },
    "serverInfo": {
      "name": "SalesforceMcpServer",
      "version": "1.1.0"
    }
  }
}
```

| Result Field | Type | Required | Description |
|---|---|---|---|
| protocolVersion | string | Yes | Server's supported protocol version |
| capabilities | object | Yes | Server capabilities (tools, resources, prompts as registered) |
| serverInfo | object | Yes | Server name (required) and version (optional) |
| instructions | string | No | LLM guidance hints |

### `notifications/initialized`

**Direction**: client → server (notification, no response)

```json
{
  "jsonrpc": "2.0",
  "method": "notifications/initialized"
}
```

### `ping`

**Direction**: either → either

**Request**:
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "ping"
}
```

**Response**:
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "result": {}
}
```

---

## Tools Capability

### `tools/list`

**Direction**: client → server

**Request**:
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/list",
  "params": {}
}
```

| Param | Type | Required | Description |
|---|---|---|---|
| cursor | string | No | Pagination cursor (not implemented in v1) |

**Response**:
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "result": {
    "tools": [
      {
        "name": "query_accounts",
        "description": "Search for Salesforce Account records",
        "inputSchema": {
          "type": "object",
          "properties": {
            "searchTerm": {
              "type": "string",
              "description": "Account name search term"
            },
            "limit": {
              "type": "integer",
              "description": "Maximum number of results"
            }
          },
          "required": ["searchTerm"]
        }
      }
    ]
  }
}
```

### `tools/call`

**Direction**: client → server

**Request**:
```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "method": "tools/call",
  "params": {
    "name": "query_accounts",
    "arguments": {
      "searchTerm": "Acme",
      "limit": 10
    }
  }
}
```

| Param | Type | Required | Description |
|---|---|---|---|
| name | string | Yes | Tool name (must match a registered tool) |
| arguments | object | No | Tool input arguments (validated by tool's validate method) |

**Response** (success):
```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "[{\"Id\":\"001...\",\"Name\":\"Acme Corp\"}]"
      }
    ]
  }
}
```

**Response** (tool execution error — `isError: true`):
```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Validation failed: searchTerm must be at least 2 characters"
      }
    ],
    "isError": true
  }
}
```

**Response** (protocol error — unknown tool):
```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "error": {
    "code": -32602,
    "message": "Unknown tool: nonexistent_tool"
  }
}
```

---

## Resources Capability

### `resources/list`

**Direction**: client → server

**Request**:
```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "method": "resources/list",
  "params": {}
}
```

**Response**:
```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "result": {
    "resources": [
      {
        "uri": "salesforce://schema/Account",
        "name": "Account Schema",
        "description": "Field definitions for the Account object",
        "mimeType": "application/json"
      }
    ]
  }
}
```

### `resources/read`

**Direction**: client → server

**Request**:
```json
{
  "jsonrpc": "2.0",
  "id": 6,
  "method": "resources/read",
  "params": {
    "uri": "salesforce://schema/Account"
  }
}
```

| Param | Type | Required | Description |
|---|---|---|---|
| uri | string | Yes | Resource URI (must match a registered resource) |

**Response** (text content):
```json
{
  "jsonrpc": "2.0",
  "id": 6,
  "result": {
    "contents": [
      {
        "uri": "salesforce://schema/Account",
        "mimeType": "application/json",
        "text": "{\"fields\":[{\"name\":\"Name\",\"type\":\"string\"}]}"
      }
    ]
  }
}
```

**Response** (binary content):
```json
{
  "jsonrpc": "2.0",
  "id": 6,
  "result": {
    "contents": [
      {
        "uri": "salesforce://files/report.pdf",
        "mimeType": "application/pdf",
        "blob": "JVBERi0xLjQK..."
      }
    ]
  }
}
```

---

## Prompts Capability

### `prompts/list`

**Direction**: client → server

**Request**:
```json
{
  "jsonrpc": "2.0",
  "id": 7,
  "method": "prompts/list",
  "params": {}
}
```

**Response**:
```json
{
  "jsonrpc": "2.0",
  "id": 7,
  "result": {
    "prompts": [
      {
        "name": "summarize_opportunity",
        "description": "Generate a summary of a Salesforce Opportunity",
        "arguments": [
          {
            "name": "opportunityId",
            "description": "The Salesforce Opportunity record ID",
            "required": true
          }
        ]
      }
    ]
  }
}
```

### `prompts/get`

**Direction**: client → server

**Request**:
```json
{
  "jsonrpc": "2.0",
  "id": 8,
  "method": "prompts/get",
  "params": {
    "name": "summarize_opportunity",
    "arguments": {
      "opportunityId": "006xx000001Sv6yAAC"
    }
  }
}
```

| Param | Type | Required | Description |
|---|---|---|---|
| name | string | Yes | Prompt name (must match a registered prompt) |
| arguments | object | No | Prompt arguments (key-value strings) |

**Response**:
```json
{
  "jsonrpc": "2.0",
  "id": 8,
  "result": {
    "description": "Opportunity summary prompt",
    "messages": [
      {
        "role": "user",
        "content": {
          "type": "text",
          "text": "Summarize this Salesforce Opportunity:\n\nName: Big Deal\nAmount: $500,000\nStage: Negotiation\nClose Date: 2026-06-30"
        }
      }
    ]
  }
}
```

---

## Error Responses

### JSON-RPC Protocol Errors

| Code | Name | When Used |
|---|---|---|
| -32700 | Parse error | Malformed JSON in request body |
| -32600 | Invalid Request | Request structure invalid (missing jsonrpc, method, etc.) |
| -32601 | Method not found | Unknown JSON-RPC method |
| -32602 | Invalid params | Unknown tool/resource/prompt name, missing required params |
| -32603 | Internal error | Unhandled server exception |

**Format**:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32601,
    "message": "Method not found: unknown/method"
  }
}
```

### Proxy-Generated Errors

When Salesforce returns a non-JSON or HTTP error response (e.g., `System.LimitException`):

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32603,
    "message": "Salesforce returned HTTP 500: System.LimitException: Apex CPU time limit exceeded"
  }
}
```

### Tool Execution Errors (not protocol errors)

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "content": [
      { "type": "text", "text": "Error: No account found matching search criteria" }
    ],
    "isError": true
  }
}
```

---

## Salesforce REST Endpoint Contract

### Request (Proxy → Salesforce)

```http
POST /services/apexrest/<subscriber-endpoint-path> HTTP/1.1
Host: <instance_url>
Authorization: Bearer <access_token>
Content-Type: application/json

{ ... JSON-RPC message ... }
```

### Response (Salesforce → Proxy)

**Success** (HTTP 200):
```http
HTTP/1.1 200 OK
Content-Type: application/json

{ ... JSON-RPC response ... }
```

**Apex error** (HTTP 500 — uncatchable `System.LimitException` or unhandled exception):
```http
HTTP/1.1 500 Internal Server Error
Content-Type: application/json

[{"message":"System.LimitException: Apex CPU time limit exceeded\n...stack trace...","errorCode":"APEX_ERROR"}]
```

**Auth error** (HTTP 401 — expired/invalid token):
```http
HTTP/1.1 401 Unauthorized
Content-Type: application/json

[{"message":"Session expired or invalid","errorCode":"INVALID_SESSION_ID"}]
```

The proxy detects these patterns and translates them into MCP-compliant JSON-RPC error responses before forwarding to the client.
