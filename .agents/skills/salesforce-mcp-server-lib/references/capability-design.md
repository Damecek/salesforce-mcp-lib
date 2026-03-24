# Capability Design

## Goal

Do not start implementation until the intended MCP surface is explicit.

## Required confirmation

Lock these four capability groups with the user:

- `tools`
- `resources`
- `resource templates`
- `prompts`

For each requested capability, confirm:

- stable name
- purpose
- required input arguments
- expected output shape
- whether it is read-only or mutating

## Minimum design standard

Prefer a narrow first version. If the user asks for “a Salesforce MCP server” without details, force the conversation toward specific capabilities instead of inventing a broad surface.

Good examples:

- tool `execute_soql` with `query`
- resource `mcp://object/account/schema`
- resource template `record-summary`
- prompt `draft-follow-up-email`

## Apex authoring rules

Prefer typed Apex contracts:

- typed tool argument classes
- typed resource/template argument classes
- class-based server registration

Avoid `Map<String, Object>` for routine business contracts except at schema or protocol edges.

## Reference implementation

When the agent needs concrete shapes, inspect these local examples before generating code:

- `examples/minimal/MinimalMcpExample.apex`
- `examples/e2e-http-endpoint/ExampleMcpServerFactory.apex`
- `examples/e2e-http-endpoint/ExampleMcpEndpoint.apex`
