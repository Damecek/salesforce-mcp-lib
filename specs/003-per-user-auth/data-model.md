# Data Model: Per-User Salesforce Authentication

**Feature**: 003-per-user-auth | **Date**: 2026-04-07

## Type Definitions

### AuthConfig (extends/replaces BridgeConfig)

The runtime configuration type. Backward compatible — all existing BridgeConfig fields remain valid.

```typescript
/** Runtime configuration for the auth + HTTP bridge. */
interface AuthConfig {
  /** Salesforce instance URL (e.g., https://myorg.my.salesforce.com). Required. */
  instanceUrl: string;
  /** External Client App consumer key (client_id). Required. */
  clientId: string;
  /** External Client App consumer secret. Present → client credentials; absent → per-user auth. */
  clientSecret?: string;
  /** Apex REST endpoint path (e.g., /services/apexrest/mcp). Required. */
  endpoint: string;
  /** Stderr log level. Defaults to 'info'. */
  logLevel?: string;
  /** Force headless login (no browser auto-open). Defaults to false. */
  headless?: boolean;
  /** Port for local OAuth callback server. Defaults to 13338. */
  callbackPort?: number;
}
```

**Validation rules**:
- `instanceUrl`: Must be a valid URL (parseable by `new URL()`)
- `clientId`: Non-empty string
- `clientSecret`: Optional. When present and non-empty, enables client credentials mode
- `endpoint`: Non-empty string starting with `/`
- `callbackPort`: Integer in range 1024–65535 if provided

**State transitions**: None (immutable after parsing)

### AuthMode

```typescript
/** Determined at startup from config shape. Immutable for process lifetime. */
type AuthMode = 'client_credentials' | 'authorization_code';
```

**Derivation rule**: `config.clientSecret ? 'client_credentials' : 'authorization_code'`

### PerUserTokenData (persisted to disk)

```typescript
/** Serialized to JSON and stored in ~/.salesforce-mcp-lib/tokens/{key}.json */
interface PerUserTokenData {
  /** Salesforce OAuth access token. Short-lived (~2h depending on org settings). */
  accessToken: string;
  /** Salesforce OAuth refresh token. Long-lived, survives process restarts. */
  refreshToken: string;
  /** Salesforce instance URL returned in token response. */
  instanceUrl: string;
  /** Token type (e.g., "Bearer"). */
  tokenType: string;
  /** Epoch milliseconds when the token was issued. */
  issuedAt: number;
  /** Salesforce user identity URL (e.g., https://login.salesforce.com/id/00Dxx/005xx). */
  identityUrl: string;
}
```

**Validation rules**:
- `accessToken`: Non-empty string, length >= 20 (consistent with existing validation)
- `refreshToken`: Non-empty string
- `instanceUrl`: Valid URL
- `issuedAt`: Positive integer

**Storage key**: `sha256(instanceUrl + '|' + clientId)` → hex string → used as filename

**File permissions**: `0o600` (owner-only read/write)

**File location**: `~/.salesforce-mcp-lib/tokens/{key}.json`

### OAuthTokenResponse (existing, unchanged)

```typescript
/** Salesforce OAuth 2.0 token response. Used by both auth flows. */
interface OAuthTokenResponse {
  access_token: string;
  instance_url: string;
  token_type: string;
  id: string;
  issued_at: string;
}
```

Both client credentials and Authorization Code flows produce this same response shape. The bridge layer is auth-flow-agnostic.

### AuthStrategy (new interface)

```typescript
/** Abstract authentication strategy. Both flows implement this. */
interface AuthStrategy {
  /** Get a valid access token. May trigger login or refresh. */
  getAccessToken(): Promise<string>;
  /** Get the Salesforce instance URL. */
  getInstanceUrl(): string | null;
  /** Attempt to re-authenticate (called on 401). */
  reauthenticate(): Promise<OAuthTokenResponse>;
  /** The auth mode this strategy implements. */
  readonly mode: AuthMode;
}
```

### PkceChallenge (internal, not exported)

```typescript
/** PKCE code challenge pair, generated fresh per login attempt. */
interface PkceChallenge {
  /** Random 128-byte value, base64url-encoded. Sent in token exchange. */
  codeVerifier: string;
  /** SHA-256 hash of codeVerifier, base64url-encoded. Sent in authorize URL. */
  codeChallenge: string;
}
```

### CallbackResult (internal)

```typescript
/** Result from the local OAuth callback server. */
interface CallbackResult {
  /** Authorization code received from Salesforce. */
  code: string;
  /** State parameter for CSRF verification. */
  state: string;
}
```

## Entity Relationships

```
AuthConfig ──determines──▶ AuthMode
    │                         │
    │                         ├── 'client_credentials' ──▶ ClientCredentialsStrategy
    │                         │                                │
    │                         │                                ▼
    │                         │                          authenticate(config)
    │                         │                          (existing oauth.ts)
    │                         │
    │                         └── 'authorization_code' ──▶ PerUserAuthStrategy
    │                                                          │
    │                                                          ├── TokenStore (load/save)
    │                                                          ├── CallbackServer (login flow)
    │                                                          └── PKCE (code challenge)
    │
    └──────────▶ Bridge.forward()
                    │
                    ├── AuthStrategy.getAccessToken()
                    └── AuthStrategy.reauthenticate() (on 401)
```

## Error Types

### New Error Subclasses (all extend SalesforceAuthError)

```typescript
/** User's Salesforce credentials were rejected (wrong password, locked account, bad client_id). */
class InvalidCredentialsError extends SalesforceAuthError {
  constructor(message: string, public readonly oauthError?: string);
}

/** User doesn't have access to the External Client App or required permissions. */
class InsufficientAccessError extends SalesforceAuthError {
  constructor(message: string, public readonly oauthError?: string);
}

/** User denied consent during OAuth authorization. */
class ConsentDeniedError extends SalesforceAuthError {
  constructor(message: string);
}

/** Access token expired or was revoked. Refresh may resolve. */
class SessionExpiredError extends SalesforceAuthError {
  constructor(message: string);
}

/** Cannot reach Salesforce (network, DNS, timeout). */
class ConnectivityError extends SalesforceAuthError {
  constructor(message: string, public readonly cause?: Error);
}
```

**Mapping from Salesforce OAuth errors**:

| Salesforce `error` field | Error Class |
|--------------------------|-------------|
| `invalid_grant` | `InvalidCredentialsError` |
| `invalid_client_id` | `InvalidCredentialsError` |
| `invalid_client` | `InvalidCredentialsError` |
| `unauthorized_client` | `InsufficientAccessError` |
| `access_denied` | `ConsentDeniedError` |
| `INVALID_SESSION_ID` (in 401 body) | `SessionExpiredError` |
| Network/DNS/timeout | `ConnectivityError` |
