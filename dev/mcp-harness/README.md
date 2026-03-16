# Scratch-Only MCP Harness

This directory contains a deployable Apex MCP server harness used for external validation with `@modelcontextprotocol/inspector`.

It is intentionally kept outside `force-app/` so it is not part of the 2GP package source.

## Layout
- `force-app/`: scratch-only Apex metadata
- `inspector/`: Inspector config template and smoke-test documentation

## Workflow
1. Deploy package source:
   - `npm run org:deploy`
2. Deploy harness source:
   - `npm run harness:deploy`
3. Run Inspector smoke checks:
   - `npm run harness:inspect:smoke`
