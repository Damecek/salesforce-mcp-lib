# Tasks: Per-User Salesforce Authentication

**Input**: Design documents from `/specs/003-per-user-auth/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Not explicitly requested in spec — test tasks omitted. Tests can be added separately.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Types)

**Purpose**: Extend the type system with all new interfaces and types needed across all stories

- [ ] T001 Add AuthConfig (clientSecret optional, headless, callbackPort fields), AuthMode type, PerUserTokenData interface, PkceChallenge interface, and CallbackResult interface to `packages/salesforce-mcp-lib/src/types.ts` per data-model.md definitions — preserve all existing BridgeConfig, OAuthTokenResponse, McpSession, JsonRpcMessage exports unchanged

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can begin

**CRITICAL**: No user story work can begin until this phase is complete

- [ ] T002 [P] Add five error subclasses to `packages/salesforce-mcp-lib/src/errors.ts` — InvalidCredentialsError(message, oauthError?), InsufficientAccessError(message, oauthError?), ConsentDeniedError(message), SessionExpiredError(message), ConnectivityError(message, cause?) — all extending existing SalesforceAuthError, each with Object.setPrototypeOf pattern matching existing classes
- [ ] T003 [P] Update `packages/salesforce-mcp-lib/src/config.ts` — remove clientSecret from REQUIRED_KEYS, add FLAG_MAP entries for --headless and --callback-port, add ENV_MAP entries for SF_HEADLESS and SF_CALLBACK_PORT, add isLoginSubcommand() function that checks process.argv[2] === 'login', add parseLoginConfig() with only instanceUrl and clientId required, return AuthConfig from both parsers
- [ ] T004 Create `packages/salesforce-mcp-lib/src/authStrategy.ts` — export AuthStrategy interface (getAccessToken, getInstanceUrl, reauthenticate, mode), export detectAuthMode(config: AuthConfig): AuthMode function that returns 'client_credentials' when clientSecret is present, 'authorization_code' when absent

**Checkpoint**: Foundation ready — types, errors, config, and strategy interface in place

---

## Phase 3: User Story 1 - Individual User Login (Priority: P1)

**Goal**: A user can log in with their own Salesforce credentials via browser-based OAuth Authorization Code flow with PKCE, and all MCP requests execute under that user's identity

**Independent Test**: Configure system without client_secret, run `salesforce-mcp-lib login --instance-url ... --client-id ...`, complete browser login, then start MCP server and verify requests execute under the logged-in user's Salesforce identity (check Salesforce audit logs)

### Implementation for User Story 1

- [ ] T005 [P] [US1] Create `packages/salesforce-mcp-lib/src/callbackServer.ts` — implement startCallbackServer(options?: CallbackServerOptions): Promise\<CallbackServer\> using node:http, listen on configurable port (default 13338), accept only GET /oauth/callback, extract code and state query params, verify state matches expected value, respond with HTML success page ("Login successful! You can close this tab."), implement waitForCode() returning Promise\<CallbackResult\>, implement close(), add 120-second timeout that rejects with descriptive error, handle port-in-use by trying up to 5 incremental ports
- [ ] T006 [P] [US1] Implement PKCE and URL helpers in `packages/salesforce-mcp-lib/src/perUserAuth.ts` — generatePkceChallenge() using node:crypto randomBytes(32) + SHA-256 + base64url encoding, buildAuthorizeUrl(instanceUrl, clientId, redirectUri, codeChallenge, state) returning full Salesforce /services/oauth2/authorize URL with response_type=code, code_challenge_method=S256, all params URL-encoded
- [ ] T007 [US1] Implement exchangeCodeForTokens in `packages/salesforce-mcp-lib/src/perUserAuth.ts` — POST to {instanceUrl}/services/oauth2/token with grant_type=authorization_code, code, client_id, redirect_uri, code_verifier as form-urlencoded body, parse JSON response into OAuthTokenResponse, throw appropriate error subclasses on failure (depends on T006)
- [ ] T008 [US1] Implement openBrowser and performLogin in `packages/salesforce-mcp-lib/src/perUserAuth.ts` — openBrowser(url) using node:child_process.exec with platform detection (darwin→open, linux→xdg-open, win32→start), 5s timeout, swallow errors gracefully; performLogin(config, logger) orchestrates: generate PKCE → start callback server → build authorize URL → open browser (or print URL if headless/browser fails) → wait for code → exchange code → return OAuthTokenResponse (depends on T005, T007)
- [ ] T009 [US1] Refactor `packages/salesforce-mcp-lib/src/oauth.ts` — wrap existing authenticate/getToken/getInstanceUrl/resetTokenCache in a ClientCredentialsStrategy class implementing AuthStrategy interface, keep all four functions as module-level exports for backward compatibility by delegating to a module-level strategy instance, ensure existing test expectations remain valid
- [ ] T010 [US1] Implement PerUserAuthStrategy class and createAuthStrategy factory in `packages/salesforce-mcp-lib/src/authStrategy.ts` — PerUserAuthStrategy holds config+logger, getAccessToken() returns cached token (token refresh and persistence added in US2), reauthenticate() calls performLogin, getInstanceUrl() returns cached URL; createAuthStrategy(config, logger) returns ClientCredentialsStrategy when client_credentials mode, PerUserAuthStrategy when authorization_code mode (depends on T009, T008)
- [ ] T011 [US1] Refactor `packages/salesforce-mcp-lib/src/mcpBridge.ts` — change createBridge signature to accept AuthStrategy instead of BridgeConfig for auth, replace getToken() call with strategy.getAccessToken(), replace authenticate(config) call in 401 handler with strategy.reauthenticate(), keep BridgeConfig for endpoint/instanceUrl, update BridgeLogger import (depends on T010)
- [ ] T012 [US1] Update `packages/salesforce-mcp-lib/src/index.ts` — add routing: if isLoginSubcommand() → parseLoginConfig() → create logger → performLogin(config, logger) → log success → exit 0; else → parseConfig() → create logger → createAuthStrategy(config, logger) → strategy.getAccessToken() to authenticate → createBridge(strategy, config, logger) → startStdioListener; log auth-mode on startup; handle login subcommand errors with exit code 2 for auth failures, exit code 3 for timeout (depends on T010, T011)

**Checkpoint**: User Story 1 complete — users can log in via browser OAuth and MCP requests execute under their identity. Token persistence not yet wired (added in US2).

---

## Phase 4: User Story 2 - Persistent Sessions Across Restarts (Priority: P2)

**Goal**: After initial login, the system remembers the user's session and transparently refreshes tokens — no re-login required on restart unless the session was externally revoked

**Independent Test**: Complete login flow, shut down MCP client, restart it, verify the user is authenticated without being prompted to log in again. Then invalidate the refresh token server-side and verify the system detects it and prompts for re-login.

### Implementation for User Story 2

- [ ] T013 [P] [US2] Create `packages/salesforce-mcp-lib/src/tokenStore.ts` — implement deriveStorageKey(instanceUrl, clientId) using node:crypto sha256 hex digest of (instanceUrl + '|' + clientId), getStorageDir() returning path.join(os.homedir(), '.salesforce-mcp-lib', 'tokens'), saveTokens(instanceUrl, clientId, data: PerUserTokenData) that mkdirSync(storageDir, recursive, 0o700) then writeFileSync(filePath, JSON.stringify(data), mode 0o600), loadTokens(instanceUrl, clientId) that reads and JSON.parses with validation (return null on missing/corrupt), deleteTokens(instanceUrl, clientId) that unlinkSync with no-op on ENOENT
- [ ] T014 [US2] Implement refreshAccessToken in `packages/salesforce-mcp-lib/src/perUserAuth.ts` — POST to {instanceUrl}/services/oauth2/token with grant_type=refresh_token, refresh_token, client_id as form-urlencoded, parse response into OAuthTokenResponse, throw SessionExpiredError on invalid_grant (user must re-login), throw ConnectivityError on network failures
- [ ] T015 [US2] Integrate token persistence into PerUserAuthStrategy in `packages/salesforce-mcp-lib/src/authStrategy.ts` — on construction, attempt loadTokens and cache; getAccessToken() checks cached token → if available try to use it, on 401/failure try refreshAccessToken → on success update cached token + saveTokens, on refresh failure → performLogin → saveTokens; reauthenticate() tries refresh first, falls back to full login; performLogin success always calls saveTokens; if refresh returns new refresh_token, update stored data
- [ ] T016 [US2] Update MCP server startup in `packages/salesforce-mcp-lib/src/index.ts` — in per-user mode, log whether stored tokens were found ("Loaded stored tokens for {instanceUrl}" or "No stored credentials found"), log refresh attempts ("Refreshing access token..."), log refresh success with user identity, handle case where no tokens exist and process is in MCP server mode (not login subcommand): log error "No stored credentials found. Please log in first: salesforce-mcp-lib login --instance-url ... --client-id ..." and exit with code 2

**Checkpoint**: User Story 2 complete — sessions persist across restarts via refresh tokens. Combined with US1, users log in once and sessions auto-renew.

---

## Phase 5: User Story 3 - Backward Compatibility with Client Credentials (Priority: P3)

**Goal**: Existing deployments using client credentials (client_id + client_secret) continue to work without any configuration changes after upgrading

**Independent Test**: Use an existing v1.0.x configuration with all four required fields (instance-url, client-id, client-secret, endpoint), start the MCP server, verify all requests work identically to v1.0.x

### Implementation for User Story 3

- [ ] T017 [P] [US3] Update printUsage() in `packages/salesforce-mcp-lib/src/config.ts` — restructure help text to show two modes: "Client Credentials Mode" (--client-secret required, existing behavior) and "Per-User Auth Mode" (--client-secret omitted, run 'login' first), document --headless and --callback-port flags, show login subcommand usage
- [ ] T018 [US3] Add auth-mode logging to client credentials path in `packages/salesforce-mcp-lib/src/index.ts` — log "auth-mode: client_credentials" on startup when clientSecret is present, ensure the startup flow for client credentials follows the identical pattern as v1.0.x (parseConfig → authenticate → createBridge → startStdioListener), verify redacting logger wraps client_secret as before
- [ ] T019 [US3] Verify backward compatibility of `packages/salesforce-mcp-lib/src/oauth.ts` — ensure authenticate(), getToken(), getInstanceUrl(), resetTokenCache() module-level exports work identically to v1.0.x when called directly (ClientCredentialsStrategy delegates to same underlying logic), ensure no signature changes on these four functions

**Checkpoint**: User Story 3 complete — existing client credentials configs work unchanged. Both auth modes coexist.

---

## Phase 6: User Story 4 - Clear Auth Error Guidance (Priority: P3)

**Goal**: Authentication failures produce distinct, actionable error messages that help users resolve issues without administrator help

**Independent Test**: Deliberately trigger each auth failure scenario (invalid client_id, unauthorized user, consent denied, network unreachable, expired session) and verify each produces a specific, helpful error message

### Implementation for User Story 4

- [ ] T020 [P] [US4] Add Salesforce OAuth error-to-subclass mapping in `packages/salesforce-mcp-lib/src/perUserAuth.ts` — in exchangeCodeForTokens and refreshAccessToken, parse Salesforce error/error_description response fields, map to: invalid_grant→InvalidCredentialsError, invalid_client_id→InvalidCredentialsError, invalid_client→InvalidCredentialsError, unauthorized_client→InsufficientAccessError, access_denied→ConsentDeniedError; append user-friendly guidance per research.md R7 error table; wrap network errors in ConnectivityError
- [ ] T021 [P] [US4] Improve error classification in `packages/salesforce-mcp-lib/src/oauth.ts` — in authenticate() function, wrap network errors (req.on('error')) in ConnectivityError with "Cannot reach {instanceUrl}" message, wrap OAuth error responses in InvalidCredentialsError instead of generic SalesforceAuthError, preserve existing error message content but use specific subclasses
- [ ] T022 [US4] Update 401 handling in `packages/salesforce-mcp-lib/src/mcpBridge.ts` — on INVALID_SESSION_ID throw/use SessionExpiredError, on re-auth failure differentiate between ConnectivityError ("check network"), InvalidCredentialsError ("credentials expired, run login again"), and generic errors; update sanitized client-facing error messages to be more actionable per CLI stderr contract
- [ ] T023 [US4] Update startup error handling in `packages/salesforce-mcp-lib/src/index.ts` — catch specific error subclasses and output tailored stderr messages: InvalidCredentialsError → "credentials rejected, verify client_id/run login again", InsufficientAccessError → "user lacks Connected App access, contact admin", ConnectivityError → "cannot reach instance, check network/URL", ConsentDeniedError → "consent required, retry login"; use exit code 2 for all auth failures; add redaction of tokens in error messages from per-user auth flow

**Checkpoint**: User Story 4 complete — all auth failure scenarios produce distinct, actionable error messages

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Edge cases, security hardening, and validation across all stories

- [ ] T024 [P] Ensure all new code paths in perUserAuth.ts, tokenStore.ts, callbackServer.ts, authStrategy.ts redact access_token and refresh_token values from any log output — use the existing redactSecrets pattern from `packages/salesforce-mcp-lib/src/index.ts`, add refresh_token to the secrets list
- [ ] T025 [P] Handle edge cases in `packages/salesforce-mcp-lib/src/perUserAuth.ts` — consent denied in callback (error=access_denied query param), callback timeout message with retry instructions, mid-session account deactivation detection (401 + failed refresh → clear stored tokens + actionable message)
- [ ] T026 Handle edge case in `packages/salesforce-mcp-lib/src/callbackServer.ts` and `packages/salesforce-mcp-lib/src/perUserAuth.ts` — when callback receives error query param instead of code (Salesforce sends error + error_description on deny), parse and throw ConsentDeniedError; validate that state param matches to prevent CSRF
- [ ] T027 Validate quickstart.md flow end-to-end — verify all CLI commands, flags, env vars, exit codes, and stderr messages in specs/003-per-user-auth/quickstart.md match the actual implementation; update any discrepancies

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 (T001) — types must exist before errors/config/strategy use them
- **User Stories (Phase 3+)**: All depend on Foundational phase (Phase 2) completion
  - US1 (Phase 3) must complete before US2 (Phase 4) — token persistence builds on the login flow
  - US3 (Phase 5) can start after Phase 2 but benefits from US1 being complete (to verify both paths)
  - US4 (Phase 6) can start after Phase 2 but benefits from US1+US2 being complete (error paths exercised)
- **Polish (Phase 7)**: Depends on all user stories (Phases 3–6) being complete

### User Story Dependencies

```
Phase 1 (Setup) ──▶ Phase 2 (Foundational) ──┬──▶ Phase 3 (US1: Login) ──▶ Phase 4 (US2: Persistence)
                                               │                                       │
                                               ├──▶ Phase 5 (US3: Backward Compat) ◀──┘
                                               │                                       │
                                               └──▶ Phase 6 (US4: Error Guidance) ◀────┘
                                                                                        │
                                                                                        ▼
                                                                              Phase 7 (Polish)
```

### Within Each User Story

- Types/interfaces before implementations
- Infrastructure modules (callbackServer, tokenStore) before orchestration (perUserAuth, authStrategy)
- Strategy pattern before bridge refactoring
- Bridge refactoring before entry point (index.ts) changes

### Parallel Opportunities

- **Phase 2**: T002 (errors.ts), T003 (config.ts) can run in parallel — different files, no cross-dependencies
- **Phase 3 (US1)**: T005 (callbackServer.ts) and T006 (perUserAuth.ts PKCE) can run in parallel — independent modules
- **Phase 4 (US2)**: T013 (tokenStore.ts) can start immediately — independent new module
- **Phase 5 (US3)**: T017 (usage text) can run in parallel with other US3 tasks
- **Phase 6 (US4)**: T020 (perUserAuth errors) and T021 (oauth errors) can run in parallel — different files

---

## Parallel Example: User Story 1

```bash
# Launch independent infrastructure modules together:
Task T005: "Create callbackServer.ts — local HTTP server"
Task T006: "Implement PKCE + buildAuthorizeUrl in perUserAuth.ts"

# Then sequential flow (each depends on previous):
Task T007: "exchangeCodeForTokens in perUserAuth.ts" (needs T006)
Task T008: "openBrowser + performLogin in perUserAuth.ts" (needs T005, T007)
Task T009: "ClientCredentialsStrategy in oauth.ts" (independent of T005-T008)
Task T010: "PerUserAuthStrategy + factory in authStrategy.ts" (needs T008, T009)
Task T011: "Refactor mcpBridge.ts" (needs T010)
Task T012: "Update index.ts entry point" (needs T010, T011)
```

## Parallel Example: User Story 2

```bash
# Token store is independent of refresh implementation:
Task T013: "Create tokenStore.ts" (can start immediately in Phase 4)
Task T014: "refreshAccessToken in perUserAuth.ts" (can start immediately in Phase 4)

# Then integration (depends on T013, T014):
Task T015: "Integrate persistence into PerUserAuthStrategy"
Task T016: "Update index.ts startup with token loading"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001)
2. Complete Phase 2: Foundational (T002–T004)
3. Complete Phase 3: User Story 1 (T005–T012)
4. **STOP and VALIDATE**: Test login flow end-to-end — browser opens, user authorizes, MCP requests work under user identity
5. Deploy/demo if ready — per-user login works but tokens are not persisted (user must log in each restart)

### Incremental Delivery

1. Phase 1 + Phase 2 → Foundation ready
2. Add US1 (Phase 3) → Test: login + MCP requests under user identity → **MVP!**
3. Add US2 (Phase 4) → Test: restart without re-login → **Usable product**
4. Add US3 (Phase 5) → Test: existing client credentials config unchanged → **Upgrade-safe**
5. Add US4 (Phase 6) → Test: actionable error messages → **Production-ready**
6. Phase 7 (Polish) → Edge cases, security, validation → **Release candidate**

### File Change Summary

| File | Action | Phases |
|------|--------|--------|
| `src/types.ts` | MODIFY | Phase 1 |
| `src/errors.ts` | MODIFY | Phase 2, Phase 6 |
| `src/config.ts` | MODIFY | Phase 2, Phase 5 |
| `src/authStrategy.ts` | NEW | Phase 2, Phase 3, Phase 4 |
| `src/callbackServer.ts` | NEW | Phase 3, Phase 7 |
| `src/perUserAuth.ts` | NEW | Phase 3, Phase 4, Phase 6, Phase 7 |
| `src/oauth.ts` | MODIFY | Phase 3, Phase 5, Phase 6 |
| `src/mcpBridge.ts` | MODIFY | Phase 3, Phase 6 |
| `src/index.ts` | MODIFY | Phase 3, Phase 4, Phase 5, Phase 6, Phase 7 |
| `src/tokenStore.ts` | NEW | Phase 4 |
| `src/stdio.ts` | UNCHANGED | — |

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable (after its prerequisites)
- US1 is the only hard prerequisite for US2; US3 and US4 depend on foundational + US1
- All file paths are relative to `packages/salesforce-mcp-lib/`
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
