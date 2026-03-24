---
name: salesforce-mcp-server-lib
description: Best practices and constraints for building and wiring Salesforce MCP servers with this repository's Apex runtime, Apex REST transport, OAuth client credentials flow, and the local `salesforce-mcp-lib` stdio bridge.
---

# Salesforce MCP Server Lib

Use this skill when the task is to design, implement, wire, or validate a Salesforce MCP server with this repository.

## Expertise

- typed Apex MCP contracts for tools, resources, templates, and prompts
- Apex REST transport wiring for MCP endpoints
- local `salesforce-mcp-lib` bridge setup over `stdio`
- OAuth 2.0 client credentials requirements for bridge-to-Salesforce access
- smoke validation and agent registration flows used in this repo

## Recommended Context

Read these references as needed:

1. [setup](./references/setup.md) for repository boundaries, canonical examples, and command entry points.
2. [wiring](./references/wiring.md) before changing Apex REST endpoint shape or MCP transport wiring.
3. [auth](./references/auth.md) before any bridge run that depends on `SF_CLIENT_ID` or `SF_CLIENT_SECRET`.
4. [agent setup](./references/agent-setup.md) when exposing the server to Codex or another MCP-capable client.
5. [validation](./references/validation.md) before claiming end-to-end success.

## Hard Rules

- Prefer typed Apex DTOs and class-based MCP contracts over dynamic `Map<String, Object>` shapes except at schema edges.
- Keep the Apex runtime and the local bridge conceptually separate.
  Apex owns the remote MCP endpoint; the Node bridge owns local `stdio` exposure and OAuth authentication.
- Do not describe this repository as native Salesforce MCP support.
  It is a workaround built from an Apex runtime plus a local bridge.
- Treat `SF_CLIENT_ID` and `SF_CLIENT_SECRET` as manual local prerequisites.
  Do not try to infer them from repo files, org metadata, or script output.
- Derive endpoint URLs with `./scripts/harness-url.sh` when working in this repository.
- When protocol behavior is uncertain, verify MCP spec and Inspector behavior through Context7 instead of relying on memory.

## Expected Output

When this skill is used, produce:

- a concrete implementation or refactor plan grounded in this repository
- exact commands for bridge execution and validation
- the endpoint derivation method actually used
- explicit manual auth prerequisites when they apply
- validation results or the precise blocker that prevented validation
