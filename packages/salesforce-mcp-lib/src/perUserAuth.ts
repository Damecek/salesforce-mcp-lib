/**
 * Per-user OAuth 2.0 Authorization Code flow with PKCE.
 * T006 — PKCE challenge generation and buildAuthorizeUrl.
 * T007 — exchangeCodeForTokens.
 * T008 — openBrowser and performLogin orchestration.
 * T014 — refreshAccessToken.
 * T020 — Salesforce OAuth error-to-subclass mapping.
 * T025 — Edge cases: consent denied, timeout, mid-session deactivation.
 * T026 — Callback error parsing, state validation for CSRF.
 */

import crypto from "node:crypto";
import https from "node:https";
import http from "node:http";
import { execFile } from "node:child_process";
import { createInterface } from "node:readline";
import { URL, URLSearchParams } from "node:url";
import process from "node:process";
import type { AuthConfig, OAuthTokenResponse, PkceChallenge } from "./types.js";
import type { BridgeLogger } from "./mcpBridge.js";
import {
  InvalidCredentialsError,
  InsufficientAccessError,
  ConsentDeniedError,
  ConnectivityError,
  SessionExpiredError,
  SalesforceAuthError,
} from "./errors.js";
import { startCallbackServer } from "./callbackServer.js";

// ---------------------------------------------------------------------------
// PKCE helpers (T006)
// ---------------------------------------------------------------------------

/** Generate a PKCE code_verifier and code_challenge pair. */
export function generatePkceChallenge(): PkceChallenge {
  // 32 random bytes → 43-char base64url string (RFC 7636 recommends 32-96 bytes).
  const codeVerifier = crypto.randomBytes(32).toString("base64url");
  const codeChallenge = crypto
    .createHash("sha256")
    .update(codeVerifier)
    .digest("base64url");
  return { codeVerifier, codeChallenge };
}

/**
 * Build the Salesforce /services/oauth2/authorize URL for the Authorization Code flow.
 */
export function buildAuthorizeUrl(
  instanceUrl: string,
  clientId: string,
  redirectUri: string,
  codeChallenge: string,
  state: string,
): string {
  const url = new URL("/services/oauth2/authorize", instanceUrl);
  url.searchParams.set("response_type", "code");
  url.searchParams.set("client_id", clientId);
  url.searchParams.set("redirect_uri", redirectUri);
  url.searchParams.set("code_challenge", codeChallenge);
  url.searchParams.set("code_challenge_method", "S256");
  url.searchParams.set("state", state);
  return url.toString();
}

// ---------------------------------------------------------------------------
// Token exchange (T007)
// ---------------------------------------------------------------------------

/**
 * Exchange an authorization code for OAuth tokens.
 * POST to {instanceUrl}/services/oauth2/token with grant_type=authorization_code.
 */
export async function exchangeCodeForTokens(
  instanceUrl: string,
  clientId: string,
  code: string,
  redirectUri: string,
  codeVerifier: string,
  clientSecret?: string,
): Promise<OAuthTokenResponse> {
  const params: Record<string, string> = {
    grant_type: "authorization_code",
    code,
    client_id: clientId,
    redirect_uri: redirectUri,
    code_verifier: codeVerifier,
  };
  // Include client_secret if the External Client App requires it.
  if (clientSecret) {
    params["client_secret"] = clientSecret;
  }
  const body = new URLSearchParams(params).toString();

  const tokenUrl = new URL("/services/oauth2/token", instanceUrl);
  const responseBody = await postForm(tokenUrl, body);
  return parseTokenResponse(responseBody, instanceUrl);
}

// ---------------------------------------------------------------------------
// Token refresh (T014)
// ---------------------------------------------------------------------------

/**
 * Refresh an existing access token using a stored refresh token.
 * POST to {instanceUrl}/services/oauth2/token with grant_type=refresh_token.
 *
 * @throws {SessionExpiredError} when the refresh token is invalid/revoked (user must re-login).
 * @throws {ConnectivityError} on network failures.
 */
export async function refreshAccessToken(
  instanceUrl: string,
  clientId: string,
  refreshToken: string,
  clientSecret?: string,
): Promise<OAuthTokenResponse> {
  const params: Record<string, string> = {
    grant_type: "refresh_token",
    refresh_token: refreshToken,
    client_id: clientId,
  };
  if (clientSecret) {
    params["client_secret"] = clientSecret;
  }
  const body = new URLSearchParams(params).toString();

  const tokenUrl = new URL("/services/oauth2/token", instanceUrl);
  try {
    const responseBody = await postForm(tokenUrl, body);
    return parseTokenResponse(responseBody, instanceUrl);
  } catch (err) {
    // invalid_grant during refresh means the refresh token is expired/revoked.
    if (
      err instanceof InvalidCredentialsError &&
      err.oauthError === "invalid_grant"
    ) {
      throw new SessionExpiredError(
        "Your session has expired and the refresh token is no longer valid. Please log in again.",
      );
    }
    throw err;
  }
}

// ---------------------------------------------------------------------------
// Browser and login orchestration (T008)
// ---------------------------------------------------------------------------

/**
 * Open a URL in the user's default browser.
 * Uses platform-specific commands. Returns true on success, false on failure.
 */
export function openBrowser(url: string): Promise<boolean> {
  return new Promise<boolean>((resolve) => {
    const platform = process.platform;
    let cmd: string;
    let args: string[];

    if (platform === "darwin") {
      cmd = "open";
      args = [url];
    } else if (platform === "win32") {
      cmd = "cmd";
      args = ["/c", "start", "", url];
    } else {
      // Linux and others
      cmd = "xdg-open";
      args = [url];
    }

    // Use execFile (not exec) to avoid shell interpolation — prevents
    // command injection if the URL contains shell metacharacters like $() or `.
    execFile(cmd, args, { timeout: 5000 }, (err) => {
      resolve(!err);
    });
  });
}

/**
 * Execute the full interactive login flow:
 * 1. Generate PKCE challenge
 * 2. Start callback server
 * 3. Open browser (or print URL in headless mode)
 * 4. Wait for authorization code
 * 5. Exchange code for tokens
 */
export async function performLogin(
  config: AuthConfig,
  logger: BridgeLogger,
): Promise<OAuthTokenResponse> {
  // Generate PKCE challenge.
  const pkce = generatePkceChallenge();
  const state = crypto.randomBytes(16).toString("hex");

  // Start callback server.
  const callbackPort = config.callbackPort ?? 13338;
  logger.info(`Starting OAuth callback server on port ${callbackPort}...`);
  const server = await startCallbackServer({
    port: callbackPort,
    expectedState: state,
  });

  try {
    // Build authorize URL.
    const authorizeUrl = buildAuthorizeUrl(
      config.instanceUrl,
      config.clientId,
      server.callbackUrl,
      pkce.codeChallenge,
      state,
    );

    if (config.headless) {
      // Headless mode: print URL and also start server in case redirect works.
      logger.info("Headless mode — printing authorization URL");
      process.stderr.write(
        `\nPlease open this URL in a browser to authorize:\n${authorizeUrl}\n\n`,
      );
      process.stderr.write(
        "After authorizing, paste the full callback URL (timeout: 120s):\n",
      );

      // Race between callback server and stdin paste.
      const codeResult = await Promise.race([
        server.waitForCode(),
        readCodeFromStdin(server.callbackUrl, state),
      ]);

      logger.info("Authorization received. Exchanging code for tokens...");
      const tokens = await exchangeCodeForTokens(
        config.instanceUrl,
        config.clientId,
        codeResult.code,
        server.callbackUrl,
        pkce.codeVerifier,
        config.clientSecret,
      );
      return tokens;
    } else {
      // Interactive mode: open browser.
      logger.info("Opening browser for Salesforce login...");
      const opened = await openBrowser(authorizeUrl);

      if (!opened) {
        logger.warn(
          "Could not open browser automatically. Please open this URL manually:",
        );
        process.stderr.write(`\n${authorizeUrl}\n\n`);
      }

      logger.info(`Waiting for authorization at ${server.callbackUrl}`);
      const codeResult = await server.waitForCode();

      logger.info("Authorization received. Exchanging code for tokens...");
      const tokens = await exchangeCodeForTokens(
        config.instanceUrl,
        config.clientId,
        codeResult.code,
        server.callbackUrl,
        pkce.codeVerifier,
        config.clientSecret,
      );
      return tokens;
    }
  } finally {
    server.close();
  }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/**
 * Read authorization code from stdin (for headless mode).
 * User must paste the full callback URL so state can be validated.
 *
 * Exported for regression tests that exercise the readline settlement behavior.
 */
export function readCodeFromStdin(
  callbackUrl: string,
  expectedState: string,
  input: NodeJS.ReadableStream = process.stdin,
): Promise<{ code: string; state: string }> {
  return new Promise((resolve, reject) => {
    let settled = false;
    const rl = createInterface({
      input,
      terminal: false,
    });

    rl.once("line", (line) => {
      settled = true;
      rl.close();
      const trimmed = line.trim();
      if (!trimmed) {
        reject(
          new Error(
            "Empty input received. Paste the full callback URL shown after authorization.",
          ),
        );
        return;
      }

      try {
        resolve(
          parseHeadlessCallbackInput(trimmed, callbackUrl, expectedState),
        );
      } catch (err) {
        reject(err);
      }
    });

    rl.once("close", () => {
      if (!settled) {
        settled = true;
        reject(new Error("stdin closed without receiving the full callback URL"));
      }
    });
  });
}

export function parseHeadlessCallbackInput(
  input: string,
  callbackUrl: string,
  expectedState: string,
): { code: string; state: string } {
  const trimmed = input.trim();
  if (!trimmed) {
    throw new Error(
      "Empty input received. Paste the full callback URL shown after authorization.",
    );
  }

  let parsedUrl: URL;
  try {
    parsedUrl = new URL(trimmed);
  } catch {
    throw new Error(
      "Invalid input received. Paste the full callback URL from the browser address bar.",
    );
  }

  const expectedUrl = new URL(callbackUrl);
  if (
    parsedUrl.origin !== expectedUrl.origin ||
    parsedUrl.pathname !== expectedUrl.pathname
  ) {
    throw new Error(
      `Invalid callback URL. Paste the full callback URL for ${callbackUrl}.`,
    );
  }

  const code = parsedUrl.searchParams.get("code");
  if (!code) {
    throw new Error(
      "Missing authorization code in callback URL. Paste the full callback URL from the browser address bar.",
    );
  }

  const state = parsedUrl.searchParams.get("state");
  if (!state) {
    throw new Error(
      "Missing state in callback URL. Paste the full callback URL from the browser address bar.",
    );
  }

  if (state !== expectedState) {
    throw new Error(
      "OAuth state mismatch. Paste the full callback URL from the current login attempt.",
    );
  }

  return { code, state };
}

/**
 * Parse a Salesforce OAuth token response.
 * Maps OAuth error codes to specific error subclasses (T020).
 */
function parseTokenResponse(
  responseBody: string,
  fallbackInstanceUrl: string,
): OAuthTokenResponse {
  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(responseBody) as Record<string, unknown>;
  } catch {
    throw new SalesforceAuthError(
      `OAuth response is not valid JSON: ${responseBody.slice(0, 200)}`,
    );
  }

  // Map Salesforce error codes to specific error subclasses (T020).
  if (typeof parsed["error"] === "string") {
    const errorCode = parsed["error"] as string;
    const desc =
      typeof parsed["error_description"] === "string"
        ? (parsed["error_description"] as string)
        : "unknown";

    throw mapOAuthError(errorCode, desc);
  }

  if (typeof parsed["access_token"] !== "string") {
    throw new SalesforceAuthError("OAuth response missing access_token");
  }

  const response: OAuthTokenResponse = {
    access_token: parsed["access_token"] as string,
    instance_url: (parsed["instance_url"] as string) ?? fallbackInstanceUrl,
    token_type: (parsed["token_type"] as string) ?? "Bearer",
    id: (parsed["id"] as string) ?? "",
    issued_at: (parsed["issued_at"] as string) ?? String(Date.now()),
  };

  // Include refresh_token if present (Authorization Code flow returns it).
  if (typeof parsed["refresh_token"] === "string") {
    response.refresh_token = parsed["refresh_token"] as string;
  }

  return response;
}

/**
 * Map Salesforce OAuth error codes to specific error subclasses.
 * Appends user-friendly guidance per research.md R7 error table.
 */
function mapOAuthError(errorCode: string, description: string): Error {
  switch (errorCode) {
    case "invalid_grant":
      return new InvalidCredentialsError(
        `Your Salesforce credentials were rejected. Check your username and password, or try logging in again. (${description})`,
        errorCode,
      );
    case "invalid_client_id":
      return new InvalidCredentialsError(
        `The External Client App client ID is not recognized. Verify the client_id in your configuration. (${description})`,
        errorCode,
      );
    case "invalid_client":
      return new InvalidCredentialsError(
        `External Client App authentication failed. Verify client_id and External Client App settings. (${description})`,
        errorCode,
      );
    case "unauthorized_client":
      return new InsufficientAccessError(
        `Your Salesforce user does not have access to this External Client App. Contact your administrator. (${description})`,
        errorCode,
      );
    case "access_denied":
      return new ConsentDeniedError(
        `Authorization was denied. The application requires your consent to access Salesforce. (${description})`,
      );
    default:
      return new SalesforceAuthError(
        `OAuth error: ${errorCode} — ${description}`,
      );
  }
}

/**
 * Low-level HTTPS/HTTP POST with application/x-www-form-urlencoded body.
 * Wraps network errors in ConnectivityError (T020).
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
