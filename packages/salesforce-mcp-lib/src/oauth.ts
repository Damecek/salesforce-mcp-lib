/**
 * Salesforce OAuth 2.0 client-credentials flow.
 * T036 — authenticate, cache token, expose getter.
 * T009 — wrap in ClientCredentialsStrategy implementing AuthStrategy.
 * T021 — improved error classification with specific error subclasses.
 */

import https from "node:https";
import http from "node:http";
import { URL } from "node:url";
import type { BridgeConfig, OAuthTokenResponse } from "./types.js";
import {
  SalesforceAuthError,
  InvalidCredentialsError,
  ConnectivityError,
} from "./errors.js";
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

  const responseBody = await postForm(tokenUrl, body);

  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(responseBody) as Record<string, unknown>;
  } catch {
    throw new SalesforceAuthError(
      `OAuth response is not valid JSON: ${responseBody.slice(0, 200)}`,
    );
  }

  if (typeof parsed["error"] === "string") {
    const desc =
      typeof parsed["error_description"] === "string"
        ? parsed["error_description"]
        : "unknown";
    const errorCode = parsed["error"] as string;

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

  constructor(config: BridgeConfig, logger: BridgeLogger) {
    this.config = config;
    this.logger = logger;
  }

  async getAccessToken(): Promise<string> {
    const token = getToken();
    if (token) return token;

    // No cached token — authenticate.
    this.logger.info("Authenticating with client credentials...");
    const response = await authenticate(this.config);
    return response.access_token;
  }

  getInstanceUrl(): string | null {
    return getInstanceUrl() ?? this.config.instanceUrl;
  }

  async reauthenticate(): Promise<OAuthTokenResponse> {
    this.logger.info("Re-authenticating with client credentials...");
    return authenticate(this.config);
  }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/**
 * Low-level HTTPS/HTTP POST with application/x-www-form-urlencoded body.
 * Uses node:https or node:http based on the URL protocol.
 * T021: Wraps network errors in ConnectivityError.
 */
function postForm(url: URL, body: string): Promise<string> {
  return new Promise<string>((resolve, reject) => {
    const transport = url.protocol === "https:" ? https : http;

    const req = transport.request(
      url,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "Content-Length": Buffer.byteLength(body).toString(),
          Accept: "application/json",
        },
      },
      (res) => {
        const chunks: Buffer[] = [];
        res.on("data", (chunk: Buffer) => chunks.push(chunk));
        res.on("end", () => {
          // Always resolve — error bodies (HTTP 400 with JSON error fields)
          // are parsed by the caller so Salesforce OAuth error codes get
          // mapped to specific error subclasses (InvalidCredentialsError, etc.)
          // instead of a generic SalesforceAuthError.
          resolve(Buffer.concat(chunks).toString("utf-8"));
        });
      },
    );

    req.on("error", (err: Error) => {
      reject(
        new ConnectivityError(
          `Cannot reach ${url.origin}. Check your network connection and instance URL.`,
          err,
        ),
      );
    });

    req.write(body);
    req.end();
  });
}
