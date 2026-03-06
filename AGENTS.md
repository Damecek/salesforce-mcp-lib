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

## Engineering Rules
- Keep automation script-first and idempotent.
- Keep public docs concise and executable.
- Add/update tests with each behavior change.

## Release Hygiene
- Initialize/check package with `npm run package:init`.
- Version with `npm run release:version`.
- Promote/install only with explicit `PACKAGE_VERSION_ID`.
