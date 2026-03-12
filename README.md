# salesforce-mcp-lib

AI-first Salesforce 2GP repository with a reusable Apex MCP library built on top of ApexJsonRpc.

## Scope
- Script-first project operations.
- Scratch org deploy/test validation.
- 2GP packaging and release commands.
- Generic MCP library runtime in Apex (no domain business logic).

Out of scope in package runtime:
- Domain-specific tool/resource/template behavior.
- Consumer-specific endpoint wiring.

## Design Principles
- Follow ApexJsonRpc's current class-first API style.
- Prefer typed DTO classes for MCP arguments, results, and descriptors.
- Keep `Object` and `Map<String, Object>` only at protocol boundaries or for free-form JSON schema fragments.
- Treat examples as typed consumer patterns, not map-plumbing recipes.

## Quick Start
```bash
npm run task:prepare
```

## ApexJsonRpc Local Reference Workflow
Pin and inspect ApexJsonRpc locally before changing the library API surface.

```bash
npm run ref:apexjsonrpc
```

Defaults:
- `TARGET_ORG=sf-mcp-lib-scratch`
- `PACKAGE_VERSION_ID=04tfj000000GCRpAAO`
- `REF_DIR=/tmp/apex-json-rpc-ref`

The script installs the package and retrieves source into `/tmp/...` for local reference only. Never commit retrieved package source.

## Commands
- `npm run org:fresh`
- `npm run org:deploy`
- `npm run org:test`
- `npm run validate`
- `npm run ref:apexjsonrpc`
- `npm run package:init`
- `npm run release:version`
- `npm run release:promote`
- `npm run release:install`

## Examples
Examples live in `examples/` and are intentionally not packaged runtime defaults.

- `examples/minimal`: minimal typed server registration and request dispatch.
- `examples/e2e-http-endpoint`: full endpoint wiring with typed list/call/read/template handlers.
