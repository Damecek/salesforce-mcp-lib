# salesforce-mcp-lib Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-04-07

## Active Technologies
- TypeScript ES2022, Node.js >= 20.0.0 + Zero production dependencies. Node.js built-in modules only (`node:http`, `node:https`, `node:fs`, `node:path`, `node:crypto`, `node:os`, `node:child_process`, `node:readline`, `node:url`) (003-per-user-auth)
- File-based token persistence in `~/.salesforce-mcp-lib/tokens/` (0600 permissions) (003-per-user-auth)

- Apex (Salesforce API 65.0) + TypeScript (ES2022, Node.js >= 20) + Zero external dependencies. Apex uses platform-native APIs only. TypeScript uses Node.js built-in modules only (no production npm dependencies). JSON-RPC 2.0 core is implemented in-repo, not imported. (001-apex-mcp-server)

## Project Structure

```text
src/
tests/
```

## Commands

npm test && npm run lint

## Code Style

Apex (Salesforce API 65.0) + TypeScript (ES2022, Node.js >= 20): Follow standard conventions

## Recent Changes
- 003-per-user-auth: Added TypeScript ES2022, Node.js >= 20.0.0 + Zero production dependencies. Node.js built-in modules only (`node:http`, `node:https`, `node:fs`, `node:path`, `node:crypto`, `node:os`, `node:child_process`, `node:readline`, `node:url`)

- 001-apex-mcp-server: Added Apex (Salesforce API 65.0) + TypeScript (ES2022, Node.js >= 20) + Zero external dependencies. Apex uses platform-native APIs only. TypeScript uses Node.js built-in modules only (no production npm dependencies). JSON-RPC 2.0 core is implemented in-repo, not imported.

<!-- MANUAL ADDITIONS START -->

## Release & Tagging

After creating a new version of either package (npm or SF 2GP), commit the version change and tag the commit.

**Tag format:** `v{npm-version}-sf{sf-version}`

Example: `v1.0.3-sf1.1.0-3` means npm `salesforce-mcp-lib@1.0.3` + SF `SalesforceMcpLib@1.1.0-3`.

**Steps:**

1. Create the package version (`npm version` or `scripts/release-create.sh --target-org mcp-lib-devhub`)
2. Commit the resulting changes (`package.json` bump or new alias in `sfdx-project.json`)
3. Tag the commit: `git tag v{npm}-sf{sf}` using current versions from both `packages/salesforce-mcp-lib/package.json` and `sfdx-project.json`
4. Push tag: `git push origin --tags`

**Where to find current versions:**

- npm: `packages/salesforce-mcp-lib/package.json` → `"version"`
- SF 2GP: `sfdx-project.json` → latest entry in `"packageAliases"`

<!-- MANUAL ADDITIONS END -->
