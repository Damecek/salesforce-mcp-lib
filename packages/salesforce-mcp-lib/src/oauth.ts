/**
 * Salesforce OAuth 2.0 client-credentials flow.
 * T036 — authenticate, cache token, expose getter.
 * T009 — wrap in ClientCredentialsStrategy implementing AuthStrategy.
 * T021 — improved error classification with specific error subclasses.
 */

import { URL } from "node:url";
import type { BridgeConfig, OAuthTokenResponse } from "./types.js";
import { SalesforceAuthError, InvalidCredentialsError } from "./errors.js";
import { postForm } from "./authHttp.js";
import { safeRemoteText } from "./redact.js";
import type { AuthStrategy } from "./authStrategy.js";
import type { BridgeLogger } from "./mcpBridge.js";

/** Cached token state (module-level singleton). */
let cachedToken: string | null = null;
let cachedInstanceUrl: string | null = null;

/**
 * Authenticate against Salesforce using the client_credentials grant type.
 *
 * On success the access_token and instance_url are cached internally so
 * that subsequent calls to {@link getToken} return the latest value.
 *
 * @throws {SalesforceAuthError} on any network or authentication failure.
 */
export async function authenticate(
  config: BridgeConfig,
): Promise<OAuthTokenResponse> {
  const tokenUrl = new URL("/services/oauth2/token", config.instanceUrl);

  const body = new URLSearchParams({
    grant_type: "client_credentials",
    client_id: config.clientId,
    client_secret: config.clientSecret,
  }).toString();

  const responseBody = await postForm(tokenUrl, body, {
    timeoutMs: config.authTimeoutMs,
  });

  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(responseBody) as Record<string, unknown>;
  } catch {
    throw new SalesforceAuthError("OAuth response is not valid JSON");
  }

  if (typeof parsed["error"] === "string") {
    const desc =
      typeof parsed["error_description"] === "string"
        ? safeRemoteText(parsed["error_description"])
        : "unknown";
    const errorCode = safeRemoteText(parsed["error"] as string);

    // T021: Use specific error subclasses instead of generic SalesforceAuthError.
    if (
      errorCode === "invalid_grant" ||
      errorCode === "invalid_client_id" ||
      errorCode === "invalid_client"
    ) {
      throw new InvalidCredentialsError(
        `External Client App authentication failed. Verify client_id and External Client App settings. (${errorCode}: ${desc})`,
        errorCode,
      );
    }
    throw new SalesforceAuthError(`OAuth error: ${errorCode} - ${desc}`);
  }

  if (typeof parsed["access_token"] !== "string") {
    throw new SalesforceAuthError("OAuth response missing access_token");
  }

  const tokenResponse: OAuthTokenResponse = {
    access_token: parsed["access_token"] as string,
    instance_url: (parsed["instance_url"] as string) ?? config.instanceUrl,
    token_type: (parsed["token_type"] as string) ?? "Bearer",
    id: (parsed["id"] as string) ?? "",
    issued_at: (parsed["issued_at"] as string) ?? String(Date.now()),
  };

  // Cache for later retrieval.
  cachedToken = tokenResponse.access_token;
  cachedInstanceUrl = tokenResponse.instance_url;

  return tokenResponse;
}

/** Return the most recently cached access token, or null. */
export function getToken(): string | null {
  return cachedToken;
}

/** Return the most recently cached instance URL, or null. */
export function getInstanceUrl(): string | null {
  return cachedInstanceUrl;
}

/** Reset cached state (useful for testing). */
export function resetTokenCache(): void {
  cachedToken = null;
  cachedInstanceUrl = null;
}

// ---------------------------------------------------------------------------
// ClientCredentialsStrategy (T009)
// ---------------------------------------------------------------------------

/**
 * AuthStrategy implementation for OAuth 2.0 client_credentials flow.
 * Wraps the existing authenticate/getToken/getInstanceUrl functions.
 */
export class ClientCredentialsStrategy implements AuthStrategy {
  readonly mode = "client_credentials" as const;
  private readonly config: BridgeConfig;
  private readonly logger: BridgeLogger;
  /** The one token request in progress; every waiter shares it. */
  private inflight: Promise<OAuthTokenResponse> | null = null;
  private current: OAuthTokenResponse | null = null;

  constructor(config: BridgeConfig, logger: BridgeLogger) {
    this.config = config;
    this.logger = logger;
  }

  async getAccessToken(): Promise<string> {
    const token = getToken();
    if (token) return token;

    // No cached token — authenticate (joins a request already in flight).
    const response = await this.authenticateOnce("Authenticating with client credentials...");
    return response.access_token;
  }

  getInstanceUrl(): string | null {
    return getInstanceUrl() ?? this.config.instanceUrl;
  }

  /**
   * @param failedAccessToken The token that just got a 401. When a newer token
   *   is already cached, the 401 is stale and no new request is made.
   */
  async reauthenticate(failedAccessToken?: string): Promise<OAuthTokenResponse> {
    const token = getToken();
    if (
      failedAccessToken !== undefined &&
      token !== null &&
      token !== failedAccessToken &&
      this.current?.access_token === token
    ) {
      return this.current;
    }
    return this.authenticateOnce("Re-authenticating with client credentials...");
  }

  private authenticateOnce(message: string): Promise<OAuthTokenResponse> {
    if (this.inflight) return this.inflight;
    this.logger.info(message);
    const attempt = authenticate(this.config).then((response) => {
      this.current = response;
      return response;
    });
    this.inflight = attempt;
    const release = (): void => {
      if (this.inflight === attempt) this.inflight = null;
    };
    attempt.then(release, release);
    return attempt;
  }
}
