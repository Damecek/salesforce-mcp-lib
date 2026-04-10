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

/** Salesforce OAuth 2.0 token response (client_credentials flow). */
export interface OAuthTokenResponse {
  access_token: string;
  instance_url: string;
  token_type: string;
  id: string;
  issued_at: string;
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
