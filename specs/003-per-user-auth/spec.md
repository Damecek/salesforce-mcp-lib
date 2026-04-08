# Feature Specification: Per-User Salesforce Authentication

**Feature Branch**: `003-per-user-auth`
**Created**: 2026-04-03
**Status**: Draft
**Input**: User description: "umoznit jednotlivym uzivatelum se prihlasit pomoci jejich dedikovanych salesforce uzivatelu. misto soucasneho client credentials flow"

## Clarifications

### Session 2026-04-07

- Q: How does the system determine whether to use per-user auth or client credentials? → A: Auto-detect from credentials — if `client_secret` is present, use client credentials; if absent, use per-user login. No new config flags required.
- Q: Can a user explicitly log out or switch to a different Salesforce user? → A: No explicit logout. Sessions persist until expired or revoked server-side. To switch users, the user manually deletes stored credentials.
- Q: Should some operations fall back to a service account in per-user mode? → A: No. All operations run under the authenticated user's identity — no service account fallback. Salesforce enforces permissions natively.
- Q: Should admins use a single Connected App for both flows or separate ones? → A: Not prescribed — admin's choice. The system must work regardless of whether the same or separate Connected Apps are used for client credentials vs. per-user login.
- Q: How should headless login work when no browser is available locally? → A: Manual URL — system prints an authorization URL to the terminal; user opens it on any device, authorizes, and the system completes login (or user pastes a return code back).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Individual User Login (Priority: P1)

As a user of the MCP-connected application, I want to log in using my own dedicated Salesforce account so that all my actions in the system are performed under my own identity, with my own permissions, visibility, and audit trail.

Currently the system uses a single shared service account (client credentials) for all requests. This means every user sees the same data, has the same permissions, and all actions are logged under one generic account. With per-user authentication, each person logs in as themselves - they see only the data they are authorized to see, can only perform actions their Salesforce profile allows, and their activity is individually traceable.

**Why this priority**: This is the core value proposition of the entire feature. Without per-user login, none of the other user stories are possible. It replaces the current single-identity model with individual identity, which is the foundational change.

**Independent Test**: Can be fully tested by configuring the system for per-user login, having a user complete the login flow, and verifying that subsequent requests to Salesforce execute under that user's identity (not the shared service account).

**Acceptance Scenarios**:

1. **Given** a user has not yet logged in, **When** they start the MCP client, **Then** they are guided through a login process that authenticates them with their own Salesforce credentials
2. **Given** a user has completed the login process, **When** they make requests through MCP tools, **Then** those requests execute under their individual Salesforce identity (visible in Salesforce audit logs as their user)
3. **Given** a user is logged in, **When** they access Salesforce data, **Then** they see only the records their Salesforce profile and sharing rules allow them to see
4. **Given** a user has never used the system before, **When** they attempt to log in, **Then** the login process completes without requiring any pre-configuration beyond having a valid Salesforce user account with access to the Connected App

---

### User Story 2 - Persistent Sessions Across Restarts (Priority: P2)

As a user, I want the system to remember my login between sessions so that I do not have to re-authenticate every time I restart the MCP client.

**Why this priority**: Without persistent sessions, users would need to go through the full interactive login process on every restart, which is disruptive - especially since MCP clients may restart frequently. This makes the feature usable in practice.

**Independent Test**: Can be tested by completing login, shutting down the MCP client, restarting it, and verifying the user is still authenticated without being prompted to log in again.

**Acceptance Scenarios**:

1. **Given** a user has previously completed login, **When** they restart the MCP client, **Then** the system automatically resumes their session without requiring interactive login
2. **Given** a user's stored session has expired or been revoked, **When** they restart the MCP client, **Then** the system detects the invalid session and prompts them to log in again
3. **Given** a user's session is close to expiry, **When** the system detects this during normal operation, **Then** it automatically renews the session transparently without user interaction

---

### User Story 3 - Backward Compatibility with Client Credentials (Priority: P3)

As an administrator of a deployment that uses the current client credentials flow, I want the existing configuration to continue working unchanged so that I can adopt per-user auth incrementally without disrupting current integrations.

**Why this priority**: Many existing deployments rely on the client credentials flow for service-to-service integrations or automated workflows where per-user login is unnecessary. Breaking these would block adoption of the new version.

**Independent Test**: Can be tested by upgrading to the new version with an existing client credentials configuration and verifying all requests continue to work identically to the previous version.

**Acceptance Scenarios**:

1. **Given** a deployment configured with client credentials (client_id, client_secret, instance_url), **When** the system is upgraded to the version with per-user auth support, **Then** it continues to authenticate and operate exactly as before without any configuration changes
2. **Given** an administrator wants to switch from client credentials to per-user auth, **When** they change the configuration, **Then** the system transitions to per-user auth mode without requiring a full redeployment

---

### User Story 4 - Clear Auth Error Guidance (Priority: P3)

As a user who encounters a login problem, I want clear error messages that help me understand what went wrong and how to fix it, so that I can resolve authentication issues without needing administrator help.

**Why this priority**: Per-user auth introduces more potential failure points than client credentials (user password changes, revoked access, expired sessions, Connected App misconfiguration). Good error guidance reduces support burden.

**Independent Test**: Can be tested by deliberately triggering various auth failure scenarios and verifying each produces a helpful, actionable error message.

**Acceptance Scenarios**:

1. **Given** a user's Salesforce credentials are invalid, **When** they attempt to log in, **Then** they receive a message explaining the credentials were rejected and suggesting next steps
2. **Given** a user's account does not have access to the Connected App, **When** they attempt to log in, **Then** they receive a message explaining they need Connected App access and whom to contact
3. **Given** the Salesforce org is unreachable, **When** a user attempts to log in, **Then** they receive a message indicating a connectivity issue distinct from a credentials issue

---

### Edge Cases

- What happens when two different users try to use the same MCP client instance simultaneously? The system supports only one authenticated user per instance at a time, with clear feedback if a second user attempts to connect. To switch users, the user must manually delete the stored credentials and restart.
- What happens when a user's Salesforce account is deactivated mid-session? The system should detect the access revocation on the next request and notify the user that their session is no longer valid.
- What happens when the Connected App's OAuth settings are changed while users have active sessions? Existing sessions should continue working until their tokens expire naturally; new logins should use the updated settings.
- What happens if the user denies consent during the login process? The system should display a clear message explaining that consent is required for the application to function and offer to retry.
- What happens if the MCP client runs in a headless environment where no browser is available? The system prints an authorization URL to the terminal; the user opens it on any device, authorizes, and then the system completes login automatically or accepts a pasted return code.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST support per-user authentication where each user logs in with their own Salesforce credentials and all subsequent requests execute under that user's identity
- **FR-002**: System MUST guide the user through an interactive login flow that does not require them to manually copy/paste tokens or secrets
- **FR-003**: System MUST persist user sessions across MCP client restarts so users are not required to re-authenticate on every startup
- **FR-004**: System MUST automatically renew sessions transparently when they are near expiry, without requiring user interaction
- **FR-005**: System MUST detect expired or revoked sessions and prompt the user to re-authenticate with a clear explanation
- **FR-006**: System MUST continue to support the existing client credentials flow for backward compatibility; the system auto-detects the mode based on whether a client secret is provided (present = client credentials, absent = per-user login)
- **FR-007**: System MUST ensure that stored credentials and session tokens are kept secure and not exposed in logs, error messages, or configuration files
- **FR-008**: System MUST provide distinct, actionable error messages for different authentication failure scenarios (invalid credentials, insufficient access, connectivity issues, consent denied)
- **FR-009**: System MUST operate under the authenticated user's Salesforce permissions for all operations without exception - profile, permission sets, and sharing rules apply to every request; no service account fallback exists in per-user mode
- **FR-010**: System MUST support login for users across different Salesforce org types (production, sandbox, custom domain) by deriving the appropriate login endpoint from the configured instance URL
- **FR-011**: System MUST support a fallback login mechanism for headless/no-browser environments by printing an authorization URL to the terminal that the user can open on any device; after authorizing, the system completes login automatically or the user pastes a return code back into the terminal

### Key Entities

- **Authenticated User Session**: Represents a single user's active connection to Salesforce - includes the user's identity, access credentials, org information, and session expiry. One session per MCP client instance.
- **Authentication Configuration**: Represents the system-level settings that determine which authentication mode to use (per-user vs. client credentials) and the associated Connected App parameters.
- **Credential Store**: Secure local storage for persisted session data that survives client restarts. Must protect sensitive data at rest.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new user can complete the login process and successfully execute their first MCP tool request within 60 seconds of starting the client
- **SC-002**: After initial login, the system resumes the user's session on restart without interactive login at least 95% of the time (failures only when the session has been externally revoked or expired beyond renewal)
- **SC-003**: All requests made through the system are attributable to the individual authenticated user in Salesforce audit logs (Setup Audit Trail, Login History)
- **SC-004**: Existing deployments using client credentials flow continue to operate without any configuration changes after upgrading
- **SC-005**: Authentication-related error messages are actionable - users can resolve at least 80% of common login issues (wrong credentials, missing access, expired session) without escalating to an administrator
- **SC-006**: Session renewal happens transparently - users experience zero interruptions due to token expiry during a normal work session (up to 8 hours)

## Assumptions

- Users have a valid Salesforce user account in the target org with an active license
- The Salesforce org has an **External Client App** (API v60+) or **Connected App** configured for OAuth 2.0 Authorization Code flow with PKCE; administrators may reuse the same app for both flows or create separate ones — the system must work with either setup
- The External Client App / Connected App has `http://localhost:13338/oauth/callback` as a registered callback URL, with OAuth scopes `api` and `refresh_token` (`offline_access`) enabled
- Users have a web browser available on the same machine for the primary login flow (a fallback exists for headless environments)
- The MCP client runs on the user's local machine (not a shared server), so one authenticated session per instance is sufficient
- The existing client credentials flow is automatically selected when `client_secret` is provided; per-user auth activates when `client_secret` is absent — no explicit mode flag needed
- Secure file-based storage (`~/.salesforce-mcp-lib/tokens/`, permissions 0600) is used for persisting session credentials
- Network connectivity to Salesforce is available during login and during active usage (offline operation is out of scope)
- The Salesforce org administrator is responsible for configuring the External Client App / Connected App and granting user access to it; this feature does not automate the Salesforce-side setup — see quickstart.md for a detailed setup guide
- No explicit logout or user-switching command is in scope; sessions persist until expired/revoked, and users delete stored credentials manually to switch accounts
- Auth is invoked as a separate `login` step before starting the MCP server. MCP clients (Claude Code, Claude Desktop) start the server as a subprocess; users authenticate via the `login` subcommand in their terminal, then the MCP client's server connects using the stored tokens
