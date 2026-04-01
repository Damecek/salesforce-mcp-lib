# salesforce-mcp-lib Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-04-08

## Active Technologies
- TypeScript ES2022, Node.js >= 20.0.0 + Zero production dependencies. Node.js built-in modules only (`node:http`, `node:https`, `node:fs`, `node:path`, `node:crypto`, `node:os`, `node:child_process`, `node:readline`, `node:url`) (003-per-user-auth)
- File-based token persistence in `~/.salesforce-mcp-lib/tokens/` (0600 permissions) (003-per-user-auth)
- Claude Code markdown prompts (no compiled language; LLM-evaluated prompt files only) + Claude Code runtime (commands, hooks, file I/O tools). Zero external dependencies. (002-linkedin-content-system)
- Filesystem — all content artifacts are markdown files under `specs/002-linkedin-content-system/content/` (002-linkedin-content-system)

- Apex (Salesforce API 65.0) + TypeScript (ES2022, Node.js >= 20) + Zero external dependencies. Apex uses platform-native APIs only. TypeScript uses Node.js built-in modules only (no production npm dependencies). JSON-RPC 2.0 core is implemented in-repo, not imported. (001-apex-mcp-server)

## Project Structure

```text
packages/salesforce-mcp-lib/src/
  index.ts             # CLI entry point (login subcommand + MCP server)
  config.ts            # CLI argument / env-var parser
  types.ts             # Shared type definitions (AuthConfig, AuthMode, etc.)
  errors.ts            # Error class hierarchy (SalesforceAuthError + subclasses)
  oauth.ts             # Client credentials OAuth flow + ClientCredentialsStrategy
  authStrategy.ts      # AuthStrategy interface + PerUserAuthStrategy + factory
  perUserAuth.ts       # Authorization Code flow (PKCE, token exchange, browser)
  callbackServer.ts    # Local HTTP server for OAuth redirect callback
  tokenStore.ts        # File-based token persistence (~/.salesforce-mcp-lib/tokens/)
  mcpBridge.ts         # JSON-RPC forwarding to Salesforce Apex endpoint
  stdio.ts             # Stdio transport + levelled logger

packages/salesforce-mcp-lib/tests/
  *.test.ts            # Unit tests (node:test runner)
```

## Commands

cd packages/salesforce-mcp-lib && npm test && npm run lint

## Code Style

Apex (Salesforce API 65.0) + TypeScript (ES2022, Node.js >= 20): Follow standard conventions

## Recent Changes
- 003-per-user-auth: Implemented per-user OAuth 2.0 Authorization Code flow with PKCE. New modules: authStrategy.ts, perUserAuth.ts, callbackServer.ts, tokenStore.ts. `--client-secret` is now optional. Auth mode auto-detected from config. Login subcommand: `salesforce-mcp-lib login`. File-based token persistence in `~/.salesforce-mcp-lib/tokens/`. Five specific error subclasses (InvalidCredentialsError, InsufficientAccessError, ConsentDeniedError, SessionExpiredError, ConnectivityError). Backward compatible with client credentials flow.
- 002-linkedin-content-system: Added Claude Code markdown prompts (no compiled language; LLM-evaluated prompt files only) + Claude Code runtime (commands, hooks, file I/O tools). Zero external dependencies.

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


External Client App instead of Connected App everywhere

## Documentation

Two READMEs cover the npm proxy — keep them in sync:

- `README.md` (root) — full project docs, both auth modes, CLI reference, ECA setup
- `packages/salesforce-mcp-lib/README.md` — npm package README, concise subset (usage, CLI reference, prerequisites)

When updating CLI flags, auth flows, or usage examples in the root README, check whether `packages/salesforce-mcp-lib/README.md` needs a matching update.
<!-- MANUAL ADDITIONS END -->
