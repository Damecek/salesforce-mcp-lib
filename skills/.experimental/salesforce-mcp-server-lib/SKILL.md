---
name: salesforce-mcp-server-lib
description: Build and wire Salesforce MCP servers with the Apex runtime and the `salesforce-mcp-lib` local stdio bridge from this repository. Use when an agent needs to mitigate the lack of native Salesforce MCP support by scaffolding an Apex-based MCP server, exposing an Apex REST MCP endpoint, setting up OAuth 2.0 client credentials, deriving the endpoint URL, running smoke validation, or registering the bridge with Codex or another MCP-capable agent.
---

# Salesforce MCP Server Lib

Use this skill when the goal is to build or wire a Salesforce MCP server with this repository's Apex runtime and local bridge.

## What This Skill Covers

- Authoring the server in Apex with typed MCP contracts.
- Exposing the server through Apex REST.
- Authenticating through Salesforce OAuth 2.0 client credentials.
- Running the local `salesforce-mcp-lib` bridge over `stdio`.
- Validating the bridge and wiring it into an agent.

## Workflow

1. Read [setup](./references/setup.md) for prerequisites, package boundaries, and canonical examples.
2. Read [wiring](./references/wiring.md) before creating or modifying the Apex REST endpoint.
3. Read [auth](./references/auth.md) before any smoke run that needs `SF_CLIENT_ID` or `SF_CLIENT_SECRET`.
4. Read [agent setup](./references/agent-setup.md) when the user wants Codex or another agent to use the MCP server.
5. Read [validation](./references/validation.md) before claiming the flow works end to end.

## Hard Rules

- Prefer typed Apex DTOs and class-based MCP contracts over dynamic `Map<String, Object>` shapes except at schema edges.
- Treat the Apex runtime and the local bridge as separate layers.
  Apex serves the remote MCP endpoint; the local Node bridge is the client-facing MCP process.
- Do not describe this repository as a native Salesforce MCP solution.
  The point of the project is to mitigate Salesforce's lack of native MCP support with an Apex runtime plus a local bridge.
- Stop immediately and ask the operator to export `SF_CLIENT_ID` and `SF_CLIENT_SECRET` if they are missing.
  These values are manual prerequisites and are not discoverable from repo state.
- Derive endpoint URLs with `./scripts/harness-url.sh` instead of hand-building them when working in this repo.
- When protocol behavior is in doubt, fetch current MCP spec and Inspector docs through Context7 rather than relying on memory.

## Output Expectations

When using this skill, produce:

- a concrete Apex server/endpoint implementation plan or patch
- the exact local command to run the bridge
- the exact endpoint URL derivation method
- the exact validation sequence used
- any required manual Salesforce auth steps called out explicitly
