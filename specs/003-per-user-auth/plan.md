# Implementation Plan: Per-User Salesforce Authentication

**Branch**: `003-per-user-auth` | **Date**: 2026-04-07 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-per-user-auth/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Replace the single-identity client credentials flow with per-user OAuth 2.0 Authorization Code authentication. Each user logs in with their own Salesforce credentials via a browser-based flow (with headless fallback), and all subsequent MCP requests execute under that user's identity. Sessions persist across restarts via file-based token storage with automatic refresh. The existing client credentials flow is preserved — the system auto-detects the mode based on whether `client_secret` is present in the configuration.

## Technical Context

**Language/Version**: TypeScript ES2022, Node.js >= 20.0.0
**Primary Dependencies**: Zero production dependencies. Node.js built-in modules only (`node:http`, `node:https`, `node:fs`, `node:path`, `node:crypto`, `node:os`, `node:child_process`, `node:readline`, `node:url`)
**Storage**: File-based token persistence in `~/.salesforce-mcp-lib/tokens/` (0600 permissions)
**Testing**: Node.js built-in test runner with tsx (`node --import tsx --test`)
**Target Platform**: Node.js >= 20 on macOS, Linux, Windows
**Project Type**: Library / CLI (npm package `salesforce-mcp-lib`)
**Performance Goals**: Login completes within 60 seconds (SC-001). Token refresh <2 seconds. Zero user interruptions during 8-hour sessions (SC-006).
**Constraints**: Zero npm production dependencies. Stdio stdout reserved for JSON-RPC — all interactive output to stderr. One authenticated user per process instance.
**Scale/Scope**: Single-user CLI process. Token storage for ~1-10 org/user combinations per machine.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principle | Status | Notes |
|---|-----------|--------|-------|
| I | AI-Agent-First Development | ✅ PASS | Descriptive file names, inline docs, linear control flow |
| II | Agent-Consumable APIs | ✅ PASS | Structured typed errors, JSON-RPC conformance unchanged |
| III | Maintainability & Reusability | ✅ PASS | Zero dependencies, single-responsibility modules, shared types in types.ts |
| IV | Strong Typing | ✅ PASS | All new types defined in types.ts, no `any`, specific error classes |
| — | Tech Stack: "No other auth mechanisms in scope" | ⚠️ VIOLATION | Constitution states "OAuth 2.0 client credentials flow … No other auth mechanisms in scope for the bridge." This feature adds Authorization Code flow. See Complexity Tracking below. |

**Pre-Phase 0 Gate**: PASS with documented violation. The constitution text was written for v1 scope. This feature intentionally extends auth scope — a constitution amendment should follow feature completion.

## Project Structure

### Documentation (this feature)

```text
specs/003-per-user-auth/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   ├── cli-contract.md  # Phase 1 output — CLI interface changes
│   └── api-contract.md  # Phase 1 output — TypeScript API changes
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
packages/salesforce-mcp-lib/src/
├── types.ts             # MODIFY: Add AuthConfig, PerUserTokenData, AuthMode
├── config.ts            # MODIFY: clientSecret optional, add --headless, login subcommand
├── errors.ts            # MODIFY: Add auth-specific error subclasses
├── oauth.ts             # MODIFY: Refactor to implement AuthStrategy interface
├── authStrategy.ts      # NEW: AuthStrategy interface + factory
├── perUserAuth.ts       # NEW: Authorization Code flow implementation
├── tokenStore.ts        # NEW: File-based encrypted token persistence
├── callbackServer.ts    # NEW: Local HTTP server for OAuth redirect
├── index.ts             # MODIFY: Auth mode detection, login subcommand routing
├── mcpBridge.ts         # MODIFY: Use AuthStrategy for re-auth + token refresh
└── stdio.ts             # UNCHANGED

packages/salesforce-mcp-lib/tests/
├── perUserAuth.test.ts  # NEW: Per-user OAuth flow tests
├── tokenStore.test.ts   # NEW: Token persistence tests
├── callbackServer.test.ts # NEW: Callback server tests
├── authStrategy.test.ts # NEW: Strategy selection/factory tests
├── config.test.ts       # MODIFY: Test optional clientSecret, headless flag
└── oauth.test.ts        # MODIFY: Ensure existing client credentials tests pass
```

**Structure Decision**: Follows the existing single-package layout under `packages/salesforce-mcp-lib/src/`. Each new concern gets its own module file. No new directories in src/ — flat module structure consistent with existing codebase (6 files → 10 files).

**Salesforce-Side Prerequisite**: An External Client App (API v60+) or Connected App must be configured with OAuth Authorization Code + PKCE flow, callback URL `http://localhost:13338/oauth/callback`, and scopes `api` + `refresh_token`. See `quickstart.md` for detailed setup instructions.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Adding Authorization Code flow (constitution says "No other auth mechanisms in scope") | Per-user auth is the explicit purpose of this feature (003). The constitution text was scoped for v1.0 delivery. Supporting individual user identity requires a different OAuth grant type — client credentials cannot authenticate individual users by design. | Continuing with client credentials only: impossible to achieve per-user identity since client credentials authenticate a single integration user, not individual humans. JWT Bearer flow: requires server-side certificate management which violates the zero-dependency, user-friendly design. |

## Design Decisions

### D1: OAuth Authorization Code Flow (Web Server)

**Chosen**: Salesforce OAuth 2.0 Authorization Code flow with PKCE.

**Why**: Standard Salesforce flow for user-facing applications. Returns both access_token and refresh_token. PKCE (Proof Key for Code Exchange) eliminates the need for client_secret in the token exchange, making it safe for public/local clients. All org types support it natively.

**Rejected**:
- JWT Bearer: Requires X.509 certificate management → complex admin setup, violates simplicity goal
- Device Authorization Grant: Salesforce does not support RFC 8628
- SAML: Not applicable for API access from CLI tools
- Username-Password flow: Deprecated by Salesforce, does not support MFA

### D2: File-Based Token Storage with File Permissions

**Chosen**: Store tokens in `~/.salesforce-mcp-lib/tokens/{key}.json` with 0600 permissions.

**Why**: Zero dependencies. File permissions provide the same security model used by SSH keys (`~/.ssh/`) and Git credentials (`~/.git-credentials`). Cross-platform via Node.js `node:fs`. Storage key derived from `sha256(instanceUrl + clientId)` to support multiple orgs.

**Rejected**:
- OS Keychain (macOS Keychain, Windows Credential Manager, libsecret): Requires native bindings or child process calls to platform-specific CLIs → fragile, hard to test, platform divergence
- Encrypted file with machine-derived key: Adds complexity without meaningful security gain (key derivable on same machine)
- In-memory only: Violates FR-003 (persist across restarts)

### D3: Local HTTP Callback Server on Fixed Port

**Chosen**: Start `node:http` server on port `13338` (configurable via `--callback-port`) to receive OAuth redirect.

**Why**: Standard approach for CLI OAuth tools. Fixed port simplifies Connected App configuration (admin adds `http://localhost:13338/oauth/callback` once). Falls back to auto-detect an available port if default is occupied. The Salesforce CLI itself uses this pattern (port 1717).

**Rejected**:
- Out-of-band redirect (urn:ietf:wg:oauth:2.0:oob): Deprecated by Salesforce
- Random port each time: Admin would need wildcard callback URL configuration, not supported by Salesforce Connected Apps
- Polling-based: Adds latency, complexity, and additional API calls

### D4: Separate Login Subcommand for All MCP Client Integrations

**Chosen**: `salesforce-mcp-lib login [options]` subcommand that runs an interactive login flow and stores tokens. In headless mode (`--headless`), prints the authorization URL and reads the callback URL/code from stdin.

**Why**: The main MCP process cannot use stdin interactively (reserved for JSON-RPC). MCP clients (Claude Code, Claude Desktop) run the server as a stdio subprocess — there is no standard MCP protocol mechanism for a stdio server to request interactive authorization. A separate login subcommand runs outside the MCP client context, allowing full terminal interaction. Once tokens are stored, the main MCP process finds them on startup.

**Claude Code integration pattern**:
1. User runs `npx salesforce-mcp-lib login ...` in their terminal (one-time)
2. Configures the MCP server in Claude Code via `/mcp` or `~/.claude.json`
3. Server starts and reads stored tokens — no interactive auth needed
4. If tokens become invalid → server exits → user re-runs `login` → restarts server from `/mcp` menu

**Rejected**:
- Inline browser open in MCP server mode: Technically possible (doesn't need stdin) but confusing UX — a browser suddenly opens while Claude is starting, no clear context
- Inline stdin prompt during startup: Conflicts with JSON-RPC stdin transport
- MCP protocol-level OAuth: Only defined for HTTP transport, not stdio
- Environment variable with pre-obtained token: Requires manual token management, violates FR-002
- External auth helper process: Over-engineered for the use case

### D5: Auth Mode Auto-Detection

**Chosen**: `client_secret` present in config → client credentials flow. `client_secret` absent → per-user Authorization Code flow. No explicit mode flag.

**Why**: Matches the spec clarification. Minimizes configuration surface. Backward compatible — existing configs with client_secret work unchanged.

### D6: PKCE for Authorization Code Flow

**Chosen**: Always use PKCE (SHA-256 code challenge) with the Authorization Code flow, even though client_id is known.

**Why**: Salesforce recommends PKCE for all Authorization Code flows. Prevents authorization code interception attacks. No client_secret needed for the token exchange — the code_verifier proves possession. Uses `node:crypto` (built-in, zero dependencies).

## Post-Design Constitution Re-Check

*Re-evaluation after Phase 1 design is complete.*

| # | Principle | Status | Post-Design Notes |
|---|-----------|--------|-------------------|
| I | AI-Agent-First Development | ✅ PASS | New modules follow naming conventions (authStrategy.ts, perUserAuth.ts, tokenStore.ts, callbackServer.ts). All functions have JSDoc comments. Linear control flow — no abstract factory patterns or DI containers. |
| II | Agent-Consumable APIs | ✅ PASS | Five specific error subclasses (InvalidCredentialsError, InsufficientAccessError, etc.) replace generic string matching. JSON-RPC error format preserved on wire. MCP protocol behavior unchanged. |
| III | Maintainability & Reusability | ✅ PASS | Zero production dependencies maintained. Each module has single responsibility. AuthStrategy interface decouples bridge from auth implementation. Token storage is a separate, testable module. |
| IV | Strong Typing | ✅ PASS | AuthConfig, PerUserTokenData, AuthMode, PkceChallenge, CallbackResult — all fully typed in types.ts. No `any` types. Error subclasses are specific and typed. |
| — | Tech Stack: "No other auth mechanisms" | ⚠️ VIOLATION (documented) | Violation documented in Complexity Tracking with justification. Constitution amendment to follow after feature ships. |

**Post-Design Gate**: PASS. All four core principles satisfied. The single tech stack constraint violation is documented and justified — it's the explicit purpose of this feature.
