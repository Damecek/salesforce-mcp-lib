---
name: salesforce-mcp-server-lib
description: Use this skill when an agent needs to install `salesforce-mcp-lib` into Salesforce, confirm the Apex REST MCP endpoint, define the target tools/resources/templates/prompts, retrieve the package locally for API reference, implement the server in Apex, explain client-credentials authorization, and connect the result to Codex or another MCP-capable agent through `npx salesforce-mcp-lib`.
---

# Salesforce MCP Server Lib

Use this skill when the task is to build or connect a Salesforce MCP server with the published `salesforce-mcp-lib` package.

## Workflow

Follow this order:

1. Read [install](./references/install.md) and confirm whether the Salesforce runtime package is already installed in the target org. Install it if missing.
2. Read [endpoint](./references/endpoint.md) and confirm the full HTTPS Apex REST MCP endpoint URL.
3. Read [capability design](./references/capability-design.md) and lock the exact `tools`, `resources`, `resource templates`, and `prompts` the user wants.
4. Read [api reference](./references/api-reference.md) and retrieve the package locally before generating Apex code.
5. Implement the server with typed Apex contracts and an Apex REST endpoint.
6. Read [auth](./references/auth.md) and [agent attach](./references/agent-attach.md) to explain authorization and connect the local agent through `npx salesforce-mcp-lib`.

## Hard Rules

- Keep the architecture split explicit.
  Salesforce hosts the remote MCP server in Apex. `salesforce-mcp-lib` is the local `stdio` bridge and OAuth client-credentials edge.
- Do not tell the agent to call Salesforce directly over HTTP unless the client explicitly requires that architecture.
- Prefer typed Apex DTOs and class-based MCP contracts over dynamic `Map<String, Object>` shapes except at schema edges.
- Do not start implementation until endpoint and capability scope are confirmed.
- Do not debug transport behavior before confirming manual auth prerequisites.
- Treat `SF_CLIENT_ID` and `SF_CLIENT_SECRET` as manual local prerequisites.
  They are not discoverable from repo state, package metadata, or deploy output.
- Explain that OAuth app setup is org-side/manual, and the user must retrieve the client ID and client secret from Salesforce Setup after configuration.
- Prefer local package docs and examples over memory when generating Apex code.

## Expected Output

When this skill is used, produce:

- whether the Salesforce package/runtime is already installed or must be installed first
- the confirmed full MCP endpoint URL
- the locked list of requested `tools`, `resources`, `resource templates`, and `prompts`
- the exact local package/docs retrieval step used for API reference
- implementation guidance grounded in that retrieved API surface
- the exact authorization instructions, including manual retrieval and export of `SF_CLIENT_ID` and `SF_CLIENT_SECRET`
- the exact local bridge command using `npx salesforce-mcp-lib`
- a concrete Codex registration example when needed
- the precise auth blocker if client credentials are missing
