# salesforce-mcp-lib Development Guidelines

Last updated: 2026-10-28 (v2 docs)

## Active Technologies
- TypeScript ES2022, Node.js >= 20.0.0 + Zero production dependencies. Node.js built-in modules only (`node:http`, `node:https`, `node:fs`, `node:path`, `node:crypto`, `node:os`, `node:child_process`, `node:readline`, `node:url`) (003-per-user-auth)
- File-based token persistence in `~/.salesforce-mcp-lib/tokens/` (0600 permissions) (003-per-user-auth)

- Apex (Salesforce API 65.0) + TypeScript (ES2022, Node.js >= 20) + Zero external dependencies. Apex uses platform-native APIs only. TypeScript uses Node.js built-in modules only (no production npm dependencies). JSON-RPC 2.0 core is implemented in-repo, not imported. (001-apex-mcp-server)

## Project Structure

```text
force-app/main/mcp/classes/       # Apex MCP framework (no json-rpc/ directory since 2.0.0)
  McpServer, McpTool, McpResource, McpResourceTemplate, McpPrompt   # public API: definitions
  McpToolResult, McpResourceResult, McpPromptResult, McpCompletion   # results
  McpContent, McpResourceContents, McpAnnotations, McpIcon           # content
  McpSchema, McpRequest, McpToolAnnotations                          # schema builder, request view
  McpException, McpConfigurationException                            # handler / registration errors
  McpRuntime, McpWire, McpUriTemplate, McpProtocolException          # internals (public only for Apex scoping)
  *Test, McpTestKit                                                  # tests and shared @IsTest helper

packages/salesforce-mcp-lib/src/
  index.ts             # CLI entry point (login subcommand + MCP server)
  config.ts            # CLI argument / env-var parser (timeout, concurrency, https policy)
  types.ts             # Shared type definitions
  errors.ts            # Error class hierarchy (SalesforceAuthError + subclasses)
  protocol.ts          # Line classification, MCP routing headers, remote response interpretation, lossless compaction
  stdio.ts             # Stdio transport: line splitter, queue, 64 MiB budget, concurrency, cancellation, backpressure
  mcpBridge.ts         # Forwarding to the Apex endpoint, one deadline, 401 retry
  authStrategy.ts      # AuthStrategy interface + PerUserAuthStrategy + factory
  authHttp.ts          # Bounded OAuth form POST (30 s total deadline, 1 MiB cap)
  oauth.ts             # Client credentials flow
  perUserAuth.ts       # Authorization Code flow (PKCE, token exchange, browser)
  callbackServer.ts    # Local HTTP server for the OAuth redirect
  tokenStore.ts        # File-based token persistence (~/.salesforce-mcp-lib/tokens/)
  urlPolicy.ts, redact.ts  # https-or-loopback rule, bounded error text

packages/salesforce-mcp-lib/tests/
  *.test.ts            # node:test runner; npmConsumer.smoke.test.ts packs and installs the tarball

docs/                  # architecture.md, mcp-wire-contract-2026-07-28.md, superpowers/ (design, plans, reports)
.github/workflows/ci.yml   # npm only: Node 20 and 22, no Salesforce secrets
```

## Commands

cd packages/salesforce-mcp-lib && npm test && npm run lint

## Code Style

Apex (Salesforce API 65.0) + TypeScript (ES2022, Node.js >= 20): Follow standard conventions

## Recent Changes
- v2 (merged from feat/mcp-v2; npm 2.0.0 published): Breaking rewrite. Apex core rebuilt (`McpServer(name, version)`, `.tool/.resource/.resourceTemplate/.prompt`, `.handle`, `McpSchema`, `McpRequest`); `json-rpc/` layer and 1.x classes deleted. Dual era MCP `2026-07-28` + `2025-11-25`. Proxy adds routing headers, `--request-timeout-ms`, `--max-concurrency`, https-only URLs (loopback excepted), byte budget, cancellation. Versions: npm 2.0.0 (published), SF 2.0.0.1 `04tdL000000qXzBQAU` (promoted, released; same package id). No per-tool rate limiting (known gap), no SSE/tasks/MRTR/subscriptions/logging. Install and upgrade verified only in scratch orgs, not on a real 1.x org. Release scripts need `--target-dev-hub` or `SF_DEVHUB`. Docs: `docs/mcp-wire-contract-2026-07-28.md`.
- 003-per-user-auth: Implemented per-user OAuth 2.0 Authorization Code flow with PKCE. New modules: authStrategy.ts, perUserAuth.ts, callbackServer.ts, tokenStore.ts. `--client-secret` is now optional. Auth mode auto-detected from config. Login subcommand: `salesforce-mcp-lib login`. File-based token persistence in `~/.salesforce-mcp-lib/tokens/`. Five specific error subclasses (InvalidCredentialsError, InsufficientAccessError, ConsentDeniedError, SessionExpiredError, ConnectivityError). Backward compatible with client credentials flow.

- 001-apex-mcp-server: Added Apex (Salesforce API 65.0) + TypeScript (ES2022, Node.js >= 20) + Zero external dependencies. Apex uses platform-native APIs only. TypeScript uses Node.js built-in modules only (no production npm dependencies). JSON-RPC 2.0 core is implemented in-repo, not imported.

<!-- MANUAL ADDITIONS START -->

## Release & Tagging

Never create a package version, publish, tag or push without the user's go. No Dev Hub is hardcoded: pass `--target-dev-hub <hub that owns package 0HodL0000002PQXSA2>` or set `SF_DEVHUB`. Code coverage and validation are never skipped.

After creating a new version of either package (npm or SF 2GP), commit the version change and tag the commit.

**Tag format:** `v{npm-version}-sf{sf-version}`

Example: `v1.0.3-sf1.1.0-3` means npm `salesforce-mcp-lib@1.0.3` + SF `SalesforceMcpLib@1.1.0-3`.

**Steps:**

1. Create the package version (`npm version` or `scripts/release-create.sh --target-dev-hub <hub>`)
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

The SF package 2.0.0.1 (`04tdL000000qXzBQAU`) is released; its install URL is `https://login.salesforce.com/packaging/installPackage.apexp?p0=04tdL000000qXzBQAU`. npm 2.0.0 is published (`npx salesforce-mcp-lib@2.0.0`). Do not publish a made-up install URL.

When updating CLI flags, auth flows, or usage examples in the root README, check whether `packages/salesforce-mcp-lib/README.md` needs a matching update.
<!-- MANUAL ADDITIONS END -->
