# MCP Wire-Contract Audit Against Spec 2025-11-25

## Summary

This audit compares the current Apex MCP server wire responses with the MCP specification dated `2025-11-25`, using the observed `MCP Inspector v0.15.0` failure on `tools/list` as the primary compatibility signal.

Primary conclusion:

- The current `tools/list` response is not spec-compliant because [`McpListedTool.cls`](/Users/adam/IdeaProjects/salesforce-mcp-lib/force-app/main/default/classes/McpListedTool.cls) omits `inputSchema`.
- The current `annotations` payload is brittle for strict clients because [`McpToolAnnotations.cls`](/Users/adam/IdeaProjects/salesforce-mcp-lib/force-app/main/default/classes/McpToolAnnotations.cls) allows unset booleans that serialize as `null`.
- Neighboring list/result payloads are not confirmed broken today, but they use the same DTO-to-JSON pattern and should be reviewed together during implementation.

## Inputs And Scope

Sources used:

- MCP spec from Context7 library `websites/modelcontextprotocol_io_specification_2025-11-25`
- Current Apex DTOs and handlers in `force-app/main/default/classes`
- Existing local fixtures in [`McpServerTest.cls`](/Users/adam/IdeaProjects/salesforce-mcp-lib/force-app/main/default/classes/McpServerTest.cls)
- Reported failing org log record `Log__c a1pAU00000IDNpFYAX` from `carvago-dev`

Scope:

- `tools/list` is the primary audited response
- `tools/call`, `prompts/list`, `resources/list`, and `resources/templates/list` are secondary compatibility checkpoints
- This document recommends implementation changes but does not apply them

## Observed Current Behavior

### Confirmed failing shape from Inspector

Reported Inspector error:

```json
[
  {
    "code": "invalid_type",
    "expected": "object",
    "received": "undefined",
    "path": ["tools", 0, "inputSchema"]
  },
  {
    "code": "invalid_type",
    "expected": "boolean",
    "received": "null",
    "path": ["tools", 0, "annotations", "destructiveHint"]
  },
  {
    "code": "invalid_type",
    "expected": "boolean",
    "received": "null",
    "path": ["tools", 0, "annotations", "openWorldHint"]
  }
]
```

Observed failing payload shape from the user-provided log:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "tools": [
      {
        "name": "opportunity.fetch_with_assets",
        "description": "Fetches one Opportunity with related Opportunity Assets.",
        "annotations": {
          "readOnlyHint": true,
          "openWorldHint": null,
          "idempotentHint": true,
          "destructiveHint": null
        }
      }
    ]
  }
}
```

### Locally reproducible equivalent shape

The local test fixture in [`McpServerTest.cls`](/Users/adam/IdeaProjects/salesforce-mcp-lib/force-app/main/default/classes/McpServerTest.cls) registers one tool with:

- explicit `inputSchema`
- `readOnlyHint = true`
- `idempotentHint = true`
- `destructiveHint` unset
- `openWorldHint` unset

`tools/list` currently serializes via:

- [`McpJsonRpcModuleBuilder.cls`](/Users/adam/IdeaProjects/salesforce-mcp-lib/force-app/main/default/classes/McpJsonRpcModuleBuilder.cls) `ToolsListHandler`
- [`McpToolsListResult.cls`](/Users/adam/IdeaProjects/salesforce-mcp-lib/force-app/main/default/classes/McpToolsListResult.cls)
- [`McpListedTool.cls`](/Users/adam/IdeaProjects/salesforce-mcp-lib/force-app/main/default/classes/McpListedTool.cls)

That path copies only:

- `name`
- `description`
- `annotations`

It does not copy `inputSchema`, so the wire payload cannot satisfy the spec even when the underlying tool definition provides one.

## Spec Baseline

From the MCP spec `2025-11-25`:

- `tools/list` returns `result.tools[]`
- Each tool entry includes `name`, optional `title`, optional `description`, and `inputSchema`
- A no-arg tool should still expose an object schema; the spec example uses an object schema with `additionalProperties: false`
- `tools/call` returns `result.content[]` and `result.isError`
- Tool annotations are optional metadata flags; when present they must be booleans, not `null`

## `tools/list` Spec-Vs-Current Matrix

| Field | Spec status | Current implementation | Current wire behavior | Delta | Recommended fix |
| --- | --- | --- | --- | --- | --- |
| `name` | Required | Present on [`McpListedTool.cls`](/Users/adam/IdeaProjects/salesforce-mcp-lib/force-app/main/default/classes/McpListedTool.cls) | Emitted | Compliant | Keep as-is |
| `title` | Optional | No field on [`McpToolDefinition.cls`](/Users/adam/IdeaProjects/salesforce-mcp-lib/force-app/main/default/classes/McpToolDefinition.cls) or [`McpListedTool.cls`](/Users/adam/IdeaProjects/salesforce-mcp-lib/force-app/main/default/classes/McpListedTool.cls) | Omitted | Acceptable gap | Optional future enhancement, not blocker |
| `description` | Optional | Present on tool definition and listed DTO | Emitted | Compliant | Keep as-is |
| `inputSchema` | Required in practice and treated as required by Inspector | Present on [`McpToolDefinition.cls`](/Users/adam/IdeaProjects/salesforce-mcp-lib/force-app/main/default/classes/McpToolDefinition.cls), absent on [`McpListedTool.cls`](/Users/adam/IdeaProjects/salesforce-mcp-lib/force-app/main/default/classes/McpListedTool.cls) | Missing | Blocking defect | Add `inputSchema` to listed DTO and validate it is always emitted |
| `annotations.readOnlyHint` | Optional boolean | Present on [`McpToolAnnotations.cls`](/Users/adam/IdeaProjects/salesforce-mcp-lib/force-app/main/default/classes/McpToolAnnotations.cls) | Emits boolean when set | Compliant when set | Keep, but normalize unset fields |
| `annotations.destructiveHint` | Optional boolean | Present on annotations DTO | Emits `null` when unset | Invalid for strict clients | Omit when unset or normalize to explicit boolean |
| `annotations.idempotentHint` | Optional boolean | Present on annotations DTO | Emits boolean when set | Compliant when set | Keep, but normalize unset fields |
| `annotations.openWorldHint` | Optional boolean | Present on annotations DTO | Emits `null` when unset | Invalid for strict clients | Omit when unset or normalize to explicit boolean |
| `icons` | Optional | No support | Omitted | Acceptable gap | Leave unsupported for now |
| `nextCursor` | Optional pagination field on list response | No support on [`McpToolsListResult.cls`](/Users/adam/IdeaProjects/salesforce-mcp-lib/force-app/main/default/classes/McpToolsListResult.cls) | Omitted | Acceptable gap for single-page responses | Leave unsupported unless pagination is added |

## Adjacent Payload Audit

### `tools/call`

[`McpToolResult.cls`](/Users/adam/IdeaProjects/salesforce-mcp-lib/force-app/main/default/classes/McpToolResult.cls) already aligns with the core spec shape:

- `content` is required and initialized
- `isError` is required and defaults to `false`

Risk level: low. The main follow-up is to keep raw JSON assertions in tests so this remains stable.

### `prompts/list`

[`McpListedPrompt.cls`](/Users/adam/IdeaProjects/salesforce-mcp-lib/force-app/main/default/classes/McpListedPrompt.cls) may serialize `arguments: null` when no prompt arguments are defined.

Assessment:

- Not a confirmed client failure
- Same null-handling risk class as tool annotations
- Should be checked during implementation if strict clients expect omission instead of `null`

### `resources/list`

[`McpResourceDefinition.cls`](/Users/adam/IdeaProjects/salesforce-mcp-lib/force-app/main/default/classes/McpResourceDefinition.cls) exposes optional `description` and `mimeType`.

Assessment:

- Required fields `uri` and `name` are validated
- Optional fields may serialize as `null`
- Lower risk than `tools/list`, but still part of the same serialization policy question

### `resources/templates/list`

[`McpListedResourceTemplate.cls`](/Users/adam/IdeaProjects/salesforce-mcp-lib/force-app/main/default/classes/McpListedResourceTemplate.cls) validates required `name` and `uriTemplate`, but optional `description` may serialize as `null`.

Assessment:

- No spec blocker identified
- Same null-policy risk applies

## Annotation Handling Decision

### Options considered

1. Emit explicit defaults for all annotation booleans
2. Omit unset annotation fields
3. Keep emitting `null`

### Recommendation

Use a mixed strategy:

- For `tools/list`, always emit a valid `inputSchema`
- For annotation booleans, omit unset fields instead of emitting `null`

Rationale:

- The spec models these annotation hints as optional booleans with defaults
- Client-side validators accept missing optional fields more reliably than `null`
- Omitting unset fields preserves the semantic difference between "not declared" and "explicitly declared"
- Explicit defaults can be introduced later if the library wants a stronger normalization policy, but they are not required to resolve the current interoperability defect

Do not keep the current `null` behavior.

## Serialization Boundary Assessment

Current serialization boundary:

- JSON-RPC responses are returned through [`McpHttpTransport.cls`](/Users/adam/IdeaProjects/salesforce-mcp-lib/force-app/main/default/classes/McpHttpTransport.cls) using `executionResult.toJson()`
- MCP DTOs rely on generic object serialization rather than MCP-specific wire shaping

### Options

1. Local DTO hardening only
2. Global MCP-specific null-suppression serialization
3. Mixed approach

### Recommendation

Use a mixed approach:

- Fix the confirmed contract bug locally in `McpListedTool`
- Add MCP-specific shaping for optional fields that must never appear as `null` to strict clients
- Keep broader serialization changes scoped to MCP DTOs, not the entire JSON-RPC runtime

Rationale:

- Local DTO hardening is required anyway because `inputSchema` is missing from the actual listed tool type
- Global runtime serialization changes are higher risk because JSON-RPC is shared infrastructure
- MCP-specific shaping gives a path to normalize prompts/resources/templates consistently without altering unrelated JSON-RPC behavior

## Likely Implementation Changes

The implementation phase should make these contract changes:

- Add `inputSchema` to [`McpListedTool.cls`](/Users/adam/IdeaProjects/salesforce-mcp-lib/force-app/main/default/classes/McpListedTool.cls)
- Ensure every listed tool emits `inputSchema`, even for no-arg tools
- Define a default no-arg schema consistent with the spec example:

```json
{
  "type": "object",
  "additionalProperties": false
}
```

- Prevent unset annotation booleans from serializing as `null`
- Expand tests to validate serialized raw response shape, not only deserialized field access

## Acceptance Tests For Implementation Phase

Add or expand tests so they assert:

1. `tools/list` returns `inputSchema` for every tool
2. A tool with no explicitly configured schema still returns a valid object schema
3. `annotations` contains only booleans for emitted hint fields
4. Unset annotation hint fields are absent, not `null`
5. `tools/call` still returns `content[]` and `isError`
6. Existing batch list responses remain valid after the tool DTO change

Recommended concrete coverage:

- Extend [`McpServerTest.cls`](/Users/adam/IdeaProjects/salesforce-mcp-lib/force-app/main/default/classes/McpServerTest.cls) `testInitializeAndLists`
- Add one regression test for a no-arg tool without explicit `inputSchema`
- Add one raw JSON assertion path in [`McpHttpTransportTest.cls`](/Users/adam/IdeaProjects/salesforce-mcp-lib/force-app/main/default/classes/McpHttpTransportTest.cls) or server tests to guard serialized output

## Conclusion

The current blocker is a wire-contract bug, not an auth or transport bug.

The minimum implementation to restore Inspector compatibility is:

- emit `inputSchema` in `tools/list`
- stop emitting `null` for optional annotation booleans

The preferred long-term fix is a mixed strategy: local `McpListedTool` hardening plus MCP-specific normalization for optional wire fields.
