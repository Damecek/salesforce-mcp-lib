# API Contract: Per-User Salesforce Authentication

**Feature**: 003-per-user-auth | **Date**: 2026-04-07

## Module Exports

### `types.ts` — Type Definitions

```typescript
// EXISTING (preserved, backward compatible)
export interface BridgeConfig { ... }           // Unchanged
export interface OAuthTokenResponse { ... }     // Unchanged
export interface McpSession { ... }             // Unchanged
export interface JsonRpcMessage { ... }         // Unchanged

// NEW
export interface AuthConfig { ... }             // Extends BridgeConfig concept, clientSecret optional
export interface PerUserTokenData { ... }       // Persisted token shape
export type AuthMode = 'client_credentials' | 'authorization_code';
```

### `authStrategy.ts` — Authentication Strategy

```typescript
export interface AuthStrategy {
  /** Get a valid access token (may trigger refresh). */
  getAccessToken(): Promise<string>;
  /** Get the active Salesforce instance URL. */
  getInstanceUrl(): string | null;
  /** Force re-authentication (called on 401). */
  reauthenticate(): Promise<OAuthTokenResponse>;
  /** Which auth mode this strategy implements. */
  readonly mode: AuthMode;
}

/**
 * Create the appropriate auth strategy based on config.
 * client_secret present → ClientCredentialsStrategy
 * client_secret absent  → PerUserAuthStrategy
 */
export function createAuthStrategy(config: AuthConfig, logger: BridgeLogger): AuthStrategy;

/**
 * Detect auth mode from config without creating a strategy.
 */
export function detectAuthMode(config: AuthConfig): AuthMode;
```

### `oauth.ts` — Client Credentials (existing, refactored)

```typescript
// EXISTING exports preserved for backward compatibility
export function authenticate(config: BridgeConfig): Promise<OAuthTokenResponse>;
export function getToken(): string | null;
export function getInstanceUrl(): string | null;
export function resetTokenCache(): void;

// Internal: now also implements AuthStrategy interface via ClientCredentialsStrategy class
```

### `perUserAuth.ts` — Per-User Authorization Code Flow

```typescript
/**
 * Execute the full interactive login flow:
 * 1. Generate PKCE challenge
 * 2. Start callback server
 * 3. Open browser (or print URL in headless mode)
 * 4. Wait for authorization code
 * 5. Exchange code for tokens
 * 6. Store tokens
 */
export function performLogin(config: AuthConfig, logger: BridgeLogger): Promise<OAuthTokenResponse>;

/**
 * Refresh an existing access token using a stored refresh token.
 */
export function refreshAccessToken(
  instanceUrl: string,
  clientId: string,
  refreshToken: string
): Promise<OAuthTokenResponse>;
```

### `tokenStore.ts` — Token Persistence

```typescript
/**
 * Load stored tokens for the given instance+client combination.
 * Returns null if no tokens are stored or if the file is corrupt/unreadable.
 */
export function loadTokens(instanceUrl: string, clientId: string): PerUserTokenData | null;

/**
 * Save tokens for the given instance+client combination.
 * Creates the storage directory if it doesn't exist.
 * File permissions: 0600 (owner-only).
 */
export function saveTokens(instanceUrl: string, clientId: string, data: PerUserTokenData): void;

/**
 * Delete stored tokens for the given instance+client combination.
 * No-op if the file doesn't exist.
 */
export function deleteTokens(instanceUrl: string, clientId: string): void;

/**
 * Return the storage directory path (~/.salesforce-mcp-lib/tokens/).
 */
export function getStorageDir(): string;

/**
 * Derive the storage key (filename) from instance URL and client ID.
 */
export function deriveStorageKey(instanceUrl: string, clientId: string): string;
```

### `callbackServer.ts` — Local OAuth Callback Server

```typescript
export interface CallbackServerOptions {
  /** Port to listen on. Defaults to 13338. */
  port?: number;
  /** Timeout in milliseconds. Defaults to 120000 (2 minutes). */
  timeout?: number;
}

export interface CallbackServer {
  /** The port the server is actually listening on. */
  readonly port: number;
  /** The full callback URL (http://localhost:{port}/oauth/callback). */
  readonly callbackUrl: string;
  /** Wait for the authorization code. Resolves with code + state. */
  waitForCode(): Promise<CallbackResult>;
  /** Shut down the server. */
  close(): void;
}

export interface CallbackResult {
  code: string;
  state: string;
}

/**
 * Start a local HTTP server that waits for the OAuth callback.
 * Attempts the configured port first, then increments up to 5 times if occupied.
 */
export function startCallbackServer(options?: CallbackServerOptions): Promise<CallbackServer>;
```

### `errors.ts` — Error Types

```typescript
// EXISTING (preserved)
export class SalesforceAuthError extends Error { ... }
export class RemoteMcpError extends Error { ... }

// NEW — all extend SalesforceAuthError
export class InvalidCredentialsError extends SalesforceAuthError { ... }
export class InsufficientAccessError extends SalesforceAuthError { ... }
export class ConsentDeniedError extends SalesforceAuthError { ... }
export class SessionExpiredError extends SalesforceAuthError { ... }
export class ConnectivityError extends SalesforceAuthError { ... }
```

### `config.ts` — Configuration Parsing

```typescript
// MODIFIED: Returns AuthConfig instead of BridgeConfig
export function parseConfig(): AuthConfig;

// NEW: Detect if the first argument is a subcommand
export function isLoginSubcommand(): boolean;

// NEW: Parse config for login subcommand (different required fields)
export function parseLoginConfig(): AuthConfig;
```

### `index.ts` — Entry Point

```typescript
// MODIFIED: Routes between login subcommand and MCP server mode
// No new public exports — this is the CLI entry point
```

## Backward Compatibility Matrix

| API | v1.0.x | v2.0.0 (this feature) | Breaking? |
|-----|--------|------------------------|-----------|
| `parseConfig()` | Returns `BridgeConfig` | Returns `AuthConfig` (superset) | No ¹ |
| `authenticate(config)` | Requires `clientSecret` | Still works with `clientSecret` | No |
| `getToken()` | Returns cached token | Returns cached token (either flow) | No |
| `getInstanceUrl()` | Returns cached URL | Returns cached URL (either flow) | No |
| `createBridge(config, logger)` | Takes `BridgeConfig` | Takes `AuthConfig` + `AuthStrategy` | Yes ² |
| CLI `--client-secret` | Required | Optional | No (relaxation) |

¹ `AuthConfig` is structurally compatible with `BridgeConfig` when `clientSecret` is present.
² Bridge creation changes to accept `AuthStrategy` instead of using module-level oauth functions directly. This is an internal API change — not exposed to npm consumers (the CLI is the public interface).
