# AGENTS.md

## Mission
Maintain a clean, reusable Salesforce 2GP project baseline with script-first operations.

## Scope Boundaries
Allowed:
- Project scaffolding and automation scripts.
- Validation and CI/pipeline setup.
- Packaging/release workflows.

Not allowed by default:
- Domain business logic.
- UI features.
- Transport endpoints unless user explicitly requests them.

## Default Task Workflow
1. Create a fresh scratch org (`npm run org:fresh`).
2. Deploy full source (`npm run org:deploy`).
3. Run tests (`npm run org:test`).
4. Implement requested changes only after steps 1-3 pass.

Override is explicit: `npm run task:prepare:skip-org`.

## Source Layout
- `force-app/main/json-rpc/classes` — in-repo JSON-RPC 2.0 core (no external dependency).
- `force-app/main/mcp/classes` — MCP `2025-11-25` protocol layer.
- Both directories are deployed as one package at `force-app`.
- Scratch-only HTTP endpoints live in `dev/mcp-harness`, outside the package.

## Context7 Protocol Sources
When doing protocol work, always fetch current docs instead of relying on training data:
- JSON-RPC 2.0 spec — resolve via Context7 (`jsonrpc.org` or similar)
- MCP spec `2025-11-25` — resolve via Context7 (`websites/modelcontextprotocol_io_specification_2025-11-25`)
- MCP Inspector — resolve via Context7 for latest wire validation behavior

## Engineering Rules
- Keep automation script-first and idempotent.
- Keep public docs concise and executable.
- Add/update tests with each behavior change.
- Prefer class-first MCP contracts and typed DTOs.
- Limit generic `Object` and `Map<String, Object>` usage to schema fragments and protocol edges.
- Breaking API cleanup is acceptable when it removes unstable dynamic shapes.
- MCP wire-contract fixes should prefer current spec compliance over backward compatibility.
- Backward compatibility is not required for unstable or invalid MCP response shapes.
- The external `ApexJsonRpc` package dependency has been removed; all JSON-RPC primitives are in-repo.

## Release Hygiene
- Initialize/check package with `npm run package:init`.
- Before `npm run release:version`, run `npm run org:test` and `npm run harness:inspect:smoke` against the scratch org you intend to version from.
- Version with `npm run release:version`.
- Promote/install only with explicit `PACKAGE_VERSION_ID`.
