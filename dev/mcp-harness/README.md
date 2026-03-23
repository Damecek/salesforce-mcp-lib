# Scratch-Only MCP Harness

This directory contains deployable Apex MCP server harness endpoints used for external validation of remote MCP access patterns.

It is intentionally kept outside `force-app/` so it is not part of the 2GP package source.

## Layout
- `force-app/`: scratch-only Apex metadata
- `inspector/`: Inspector config template and smoke-test documentation

## Workflow
1. Deploy package source:
   - `npm run org:deploy`
2. Deploy harness source:
   - `npm run harness:deploy`
3. Run smoke checks:
   - `npm run harness:inspect:smoke`
   - `npm run harness:proxy:smoke`

## Endpoints
- `/services/apexrest/mcp`
- `/services/apexrest/opportunity/mcp`
