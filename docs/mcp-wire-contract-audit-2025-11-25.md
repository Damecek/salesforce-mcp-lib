# MCP Wire Contract Audit — Protocol Version 2025-11-25

**Date**: 2026-03-30
**Auditor**: Automated generation during implementation
**Package**: SalesforceMcpLib v1.1.0

## Protocol Compliance Summary

| MCP Method | Implemented | Wire Format Verified | Test Coverage |
|---|---|---|---|
| initialize | ✓ | ✓ | McpServerTest |
| notifications/initialized | ✓ | ✓ | McpServerTest |
| ping | ✓ | ✓ | McpServerTest |
| tools/list | ✓ | ✓ | McpServerTest |
| tools/call | ✓ | ✓ | McpServerTest |
| resources/list | ✓ | ✓ | McpResourceTest |
| resources/read | ✓ | ✓ | McpResourceTest |
| resources/templates/list | ✓ | ✓ | McpResourceTest |
| resources/templates/call | ✓ | ✓ | McpResourceTest |
| prompts/list | ✓ | ✓ | McpPromptTest |
| prompts/get | ✓ | ✓ | McpPromptTest |

## JSON-RPC 2.0 Compliance

| Feature | Status | Notes |
|---|---|---|
| Single request | ✓ | JsonRpcServiceRuntimeTest |
| Batch request | ✓ | JsonRpcServiceRuntimeTest |
| Notifications (no response) | ✓ | JsonRpcServiceRuntimeTest, McpServerTest |
| Error -32700 (Parse error) | ✓ | JsonRpcServiceRuntimeTest, McpServerTest |
| Error -32600 (Invalid Request) | ✓ | JsonRpcServiceRuntimeTest |
| Error -32601 (Method not found) | ✓ | JsonRpcServiceRuntimeTest, McpServerTest |
| Error -32602 (Invalid params) | ✓ | McpServerTest, McpResourceTest, McpPromptTest |
| Error -32603 (Internal error) | ✓ | JsonRpcServiceRuntimeTest |
| ID types: string, integer, null | ✓ | JsonRpcServiceRuntimeTest |

## Two-Tier Error Model

| Error Type | Implementation | Test Coverage |
|---|---|---|
| Protocol errors (JSON-RPC error) | JsonRpcError factory methods | All test classes |
| Tool execution errors (isError: true) | McpToolsCallHandler catch blocks | McpServerTest |
| Exception mapping | McpJsonRpcExceptionMapper | McpServerTest |

## Capability Negotiation

Server advertises capabilities dynamically based on registered definitions:
- `tools: {}` — present when ≥1 tool registered
- `resources: {}` — present when ≥1 resource or template registered
- `prompts: {}` — present when ≥1 prompt registered

Verified in: McpServerTest, McpResourceTest, McpPromptTest

## Proxy Error Translation

| Salesforce Response | Proxy Translation | Status |
|---|---|---|
| HTTP 200 (valid JSON-RPC) | Forward unchanged | ✓ |
| HTTP 401 (INVALID_SESSION_ID) | Re-auth + retry once | ✓ |
| HTTP 500 (APEX_ERROR) | JSON-RPC -32603 | ✓ |
| HTTP 500 (non-JSON) | JSON-RPC -32603 | ✓ |
| Network error | JSON-RPC -32603 | ✓ |
