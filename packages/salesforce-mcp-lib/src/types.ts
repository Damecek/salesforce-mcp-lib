/**
 * Core type definitions for the salesforce-mcp-lib stdio proxy.
 * T033 — shared interfaces consumed by all other modules.
 */

/** Configuration for the OAuth + HTTP bridge to Salesforce. */
export interface BridgeConfig {
  /** Salesforce instance URL, e.g. https://myorg.my.salesforce.com */
  instanceUrl: string;
  /** External-client-app consumer key (client_id). */
  clientId: string;
  /** External-client-app consumer secret (client_secret). */
  clientSecret: string;
  /** Apex REST endpoint path, e.g. /services/apexrest/mcp */
  endpoint: string;
  /** Stderr log level. Defaults to 'info'. */
  logLevel?: string;
}

/** Salesforce OAuth 2.0 token response (both client_credentials and authorization_code flows). */
export interface OAuthTokenResponse {
  access_token: string;
  instance_url: string;
  token_type: string;
  id: string;
  issued_at: string;
  /** Refresh token — present in Authorization Code flow, absent in client_credentials. */
  refresh_token?: string;
}

/** Tracks the lifecycle of the remote MCP session. */
export interface McpSession {
  sessionId: string;
  protocolVersion: string;
  serverCapabilities: Record<string, unknown>;
  state: "initializing" | "operational" | "closed";
}

/** A JSON-RPC 2.0 message (request, response, notification, or error). */
export interface JsonRpcMessage {
  jsonrpc: string;
  id?: string | number | null;
  method?: string;
  params?: Record<string, unknown>;
  result?: unknown;
  error?: {
    code: number;
    message: string;
    data?: unknown;
  };
}

// ---------------------------------------------------------------------------
// Per-User Authentication types (003-per-user-auth)
// ---------------------------------------------------------------------------

/**
 * Runtime configuration for auth + HTTP bridge.
 * Backward compatible with BridgeConfig when clientSecret is present.
 */
export interface AuthConfig {
  /** Salesforce instance URL (e.g., https://myorg.my.salesforce.com). Required. */
  instanceUrl: string;
  /** External Client App consumer key (client_id). Required. */
  clientId: string;
  /** External Client App consumer secret. Present → client credentials; absent → per-user auth. */
  clientSecret?: string;
  /** Apex REST endpoint path (e.g., /services/apexrest/mcp). Required in server mode. */
  endpoint: string;
  /** Stderr log level. Defaults to 'info'. */
  logLevel?: string;
  /** Force headless login (no browser auto-open). Defaults to false. */
  headless?: boolean;
  /** Port for local OAuth callback server. Defaults to 13338. */
  callbackPort?: number;
}

/** Determined at startup from config shape. Immutable for process lifetime. */
export type AuthMode = "client_credentials" | "authorization_code";

/** Serialized to JSON and stored in ~/.salesforce-mcp-lib/tokens/{key}.json */
export interface PerUserTokenData {
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

/** PKCE code challenge pair, generated fresh per login attempt. */
export interface PkceChallenge {
  /** Random value, base64url-encoded. Sent in token exchange. */
  codeVerifier: string;
  /** SHA-256 hash of codeVerifier, base64url-encoded. Sent in authorize URL. */
  codeChallenge: string;
}

/** Result from the local OAuth callback server. */
export interface CallbackResult {
  /** Authorization code received from Salesforce. */
  code: string;
  /** State parameter for CSRF verification. */
  state: string;
}
