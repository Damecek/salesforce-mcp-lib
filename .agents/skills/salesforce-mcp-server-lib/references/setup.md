# Setup

## Purpose

This repository provides two distinct pieces:

- Apex MCP runtime inside `force-app/main/mcp` plus the in-repo JSON-RPC core in `force-app/main/json-rpc`
- local Node bridge package in `packages/salesforce-mcp-lib` that exposes a remote Salesforce MCP endpoint over local `stdio`

The recommended architecture is:

1. implement the MCP server in Apex with this repository's runtime
2. expose it through Apex REST
3. authenticate with Salesforce OAuth client credentials
4. let local agents talk to the bridge over `stdio`

This is a mitigation for the absence of native Salesforce MCP support, not a first-party Salesforce MCP capability.

## Prerequisites

- Node.js 20+
- Salesforce CLI
- a Salesforce org where the Apex runtime and your endpoint can be deployed
- an External Client App or Connected App with client credentials flow enabled
- a configured Run As user for that app
- local secrets exported as `SF_CLIENT_ID` and `SF_CLIENT_SECRET` for bridge-based smoke tests

## Canonical Source Files

Read these first when building a new server:

- `examples/minimal/README.md`
- `examples/minimal/MinimalMcpExample.apex`
- `examples/e2e-http-endpoint/README.md`
- `packages/salesforce-mcp-lib/README.md`
- `dev/mcp-harness/README.md`

## Authoring Guidance

- Start from the minimal example when you only need server registration and typed handlers.
- Start from the E2E HTTP example when you need an actual Apex REST endpoint.
- Keep business-domain behavior out of the reusable runtime package.
- Prefer typed DTO classes for tool arguments, resource arguments, and prompt/template contracts.
- Keep public docs and operator commands executable and concise.

## Repo Commands

Core project commands:

- `npm run org:fresh`
- `npm run org:deploy`
- `npm run org:test`
- `npm run build`
- `npm run test`

Harness and bridge commands:

- `npm run harness:url`
- `npm run harness:inspect:smoke`
- `npm run harness:proxy:smoke`
- `npm run codex:mcp:smoke`

## Protocol Verification

If the task touches MCP protocol semantics, wire contract, or Inspector behavior:

- use Context7 for the MCP spec `2025-11-25`
- use Context7 for MCP Inspector
- use the local `context7-salesforce-documentation-context` skill when Salesforce documentation needs verification
