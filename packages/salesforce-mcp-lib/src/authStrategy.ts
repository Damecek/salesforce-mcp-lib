/**
 * Authentication strategy abstraction.
 * T004 — AuthStrategy interface and detectAuthMode.
 * T010 — PerUserAuthStrategy class and createAuthStrategy factory.
 * T015 — Token persistence integration (load/save/refresh).
 */

import type {
  AuthConfig,
  AuthMode,
  OAuthTokenResponse,
} from "./types.js";
import type { BridgeLogger } from "./mcpBridge.js";
import { ClientCredentialsStrategy } from "./oauth.js";
import { performLogin, refreshAccessToken } from "./perUserAuth.js";
import { loadTokens, saveTokens, deleteTokens } from "./tokenStore.js";
import type { LoadTokensResult } from "./tokenStore.js";
import { LoginRequiredError, SalesforceAuthError, SessionExpiredError } from "./errors.js";
import type { BridgeConfig } from "./types.js";
import { buildPerUserTokenData } from "./perUserTokenData.js";

/** Abstract authentication strategy. Both flows implement this. */
export interface AuthStrategy {
  /** Get a valid access token. May trigger login or refresh. */
  getAccessToken(): Promise<string>;
  /** Get the Salesforce instance URL. */
  getInstanceUrl(): string | null;
  /**
   * Attempt to re-authenticate (called on 401). `failedAccessToken` is the
   * token the rejected request carried: when a newer token is already cached,
   * the 401 is stale and the current credentials are returned without a new
   * token request. Concurrent calls share one request.
   */
  reauthenticate(failedAccessToken?: string): Promise<OAuthTokenResponse>;
  /** The auth mode this strategy implements. */
  readonly mode: AuthMode;
}

/**
 * Detect auth mode from config without creating a strategy.
 * client_secret present → client_credentials; absent → authorization_code.
 */
export function detectAuthMode(config: AuthConfig): AuthMode {
  return config.clientSecret ? "client_credentials" : "authorization_code";
}

export interface PerUserAuthStrategyOptions {
  allowInteractiveLogin?: boolean;
  loginHandler?: typeof performLogin;
  preloadedTokens?: LoadTokensResult;
}

export interface CreateAuthStrategyOptions {
  allowInteractiveLogin?: boolean;
  loginHandler?: typeof performLogin;
}

/** Internal signal: no token can be obtained without an interactive login. */
class LoginNeeded extends Error {}

function describeError(err: unknown): string {
  return err instanceof SalesforceAuthError ? err.message : err instanceof Error ? err.name : "unknown error";
}

// ---------------------------------------------------------------------------
// PerUserAuthStrategy (T010 + T015)
// ---------------------------------------------------------------------------

/**
 * AuthStrategy implementation for OAuth 2.0 Authorization Code flow with PKCE.
 * Manages cached tokens, refresh, and persistence.
 */
export class PerUserAuthStrategy implements AuthStrategy {
  readonly mode = "authorization_code" as const;
  private readonly config: AuthConfig;
  private readonly logger: BridgeLogger;
  private readonly allowInteractiveLogin: boolean;
  private readonly loginHandler: typeof performLogin;
  private cachedToken: string | null = null;
  private cachedInstanceUrl: string | null = null;
  private cachedRefreshToken: string | null = null;
  /** Latest successful token response; returned to stale 401 callers. */
  private current: OAuthTokenResponse | null = null;
  /** The one refresh or login in progress; every waiter shares it. */
  private inflight: Promise<OAuthTokenResponse> | null = null;
  private _tokensLoaded = false;

  constructor(
    config: AuthConfig,
    logger: BridgeLogger,
    options: PerUserAuthStrategyOptions = {},
  ) {
    this.config = config;
    this.logger = logger;
    this.allowInteractiveLogin = options.allowInteractiveLogin ?? true;
    this.loginHandler = options.loginHandler ?? performLogin;

    // T015: Load stored tokens, using a pre-loaded result when provided
    // (avoids a redundant disk read when called from createAuthStrategy).
    const result =
      options.preloadedTokens ??
      loadTokens(config.instanceUrl, config.clientId);
    this.applyLoadResult(result);
  }

  /** Whether stored tokens were found during construction. */
  get tokensLoaded(): boolean {
    return this._tokensLoaded;
  }

  private applyLoadResult(result: LoadTokensResult): void {
    switch (result.status) {
      case "loaded":
        this.cachedToken = result.data.accessToken;
        this.cachedInstanceUrl = result.data.instanceUrl;
        this.cachedRefreshToken = result.data.refreshToken;
        this._tokensLoaded = true;
        this.logger.info(`Loaded stored tokens for ${this.config.instanceUrl}`);
        break;
      case "corrupt":
        this.logger.warn(
          `Stored token file is corrupt (${result.reason}) — ignoring. ` +
            `Run "salesforce-mcp-lib login" to re-authenticate.`,
        );
        deleteTokens(this.config.instanceUrl, this.config.clientId);
        break;
      case "error":
        this.logger.warn(
          `Could not read stored tokens: ${result.error.message}`,
        );
        break;
      case "missing":
        this.logger.info("No stored credentials found");
        break;
    }
  }

  async getAccessToken(): Promise<string> {
    if (this.cachedToken) {
      return this.cachedToken;
    }
    try {
      return (await this.acquireOnce()).access_token;
    } catch (err) {
      if (err instanceof LoginNeeded) {
        throw new LoginRequiredError(this.buildLoginRequiredMessage());
      }
      throw err;
    }
  }

  getInstanceUrl(): string | null {
    return this.cachedInstanceUrl ?? this.config.instanceUrl;
  }

  async reauthenticate(failedAccessToken?: string): Promise<OAuthTokenResponse> {
    // A 401 for a token that was already replaced must not trigger (or wipe) anything.
    if (
      failedAccessToken !== undefined &&
      this.cachedToken !== null &&
      this.cachedToken !== failedAccessToken &&
      this.current !== null
    ) {
      return this.current;
    }
    // Requests that start while the refresh runs wait for it instead of reusing the rejected token.
    if (failedAccessToken !== undefined && this.cachedToken === failedAccessToken) {
      this.cachedToken = null;
    }
    try {
      return await this.acquireOnce();
    } catch (err) {
      if (err instanceof LoginNeeded) {
        throw new SessionExpiredError(this.buildSessionExpiredMessage());
      }
      throw err;
    }
  }

  /**
   * Refresh (or log in) once at a time. getAccessToken and reauthenticate share
   * this promise, so a rotating refresh token is redeemed by one request only.
   * The request has its own deadline, so a waiter that stops waiting does not
   * abort it for the others.
   */
  private acquireOnce(): Promise<OAuthTokenResponse> {
    if (this.inflight) return this.inflight;
    const attempt = this.acquire();
    this.inflight = attempt;
    const release = (): void => {
      if (this.inflight === attempt) this.inflight = null;
    };
    attempt.then(release, release);
    return attempt;
  }

  private async acquire(): Promise<OAuthTokenResponse> {
    if (this.cachedRefreshToken) {
      try {
        this.logger.info("Refreshing access token...");
        const response = await refreshAccessToken(
          this.config.instanceUrl,
          this.config.clientId,
          this.cachedRefreshToken,
          this.config.clientSecret,
          { timeoutMs: this.config.authTimeoutMs },
        );
        this.updateCachedTokens(response);
        this.logger.info(
          `Token refreshed successfully (identity: ${response.id})`,
        );
        return response;
      } catch (err) {
        if (err instanceof SessionExpiredError) {
          // Refresh token is invalid. Only this single flight deletes the
          // stored tokens, so a stale failure cannot wipe newly issued ones.
          this.logger.warn(
            "Refresh token expired or revoked — stored tokens cleared, will re-login",
          );
          deleteTokens(this.config.instanceUrl, this.config.clientId);
          this.clearCache();
          if (!this.allowInteractiveLogin) throw new LoginNeeded();
        } else if (!this.allowInteractiveLogin) {
          throw err;
        }
        this.logger.warn(`Token refresh failed: ${describeError(err)}`);
      }
    }

    if (!this.allowInteractiveLogin) throw new LoginNeeded();
    this.logger.info("No usable stored credentials — starting browser login flow...");
    const response = await this.loginHandler(this.config, this.logger);
    this.updateCachedTokens(response);
    return response;
  }

  private updateCachedTokens(response: OAuthTokenResponse): void {
    this.current = response;
    this.cachedToken = response.access_token;
    this.cachedInstanceUrl = response.instance_url;

    const tokenData = buildPerUserTokenData(response, this.cachedRefreshToken ?? undefined);

    // Update cached refresh token if a new one was issued.
    if (tokenData.refreshToken) {
      this.cachedRefreshToken = tokenData.refreshToken;
    }

    // T015: Persist tokens to disk.
    saveTokens(this.config.instanceUrl, this.config.clientId, tokenData);
  }

  /** Return the cached refresh token (for secret redaction). */
  getRefreshToken(): string | null {
    return this.cachedRefreshToken;
  }

  /** Drop the cached access token, but only if it is still `failedAccessToken` (when given). */
  invalidateToken(failedAccessToken?: string): void {
    if (failedAccessToken === undefined || this.cachedToken === failedAccessToken) {
      this.cachedToken = null;
    }
  }

  private clearCache(): void {
    this.cachedToken = null;
    this.cachedInstanceUrl = null;
    this.cachedRefreshToken = null;
    this.current = null;
    this._tokensLoaded = false;
  }

  private buildLoginRequiredMessage(): string {
    return (
      "No stored credentials found. Please log in first: " +
      this.buildLoginCommand()
    );
  }

  private buildSessionExpiredMessage(): string {
    return (
      "Your session has expired and cannot be refreshed. Please log in again: " +
      this.buildLoginCommand()
    );
  }

  private buildLoginCommand(): string {
    return (
      `salesforce-mcp-lib login --instance-url ${this.config.instanceUrl} ` +
      `--client-id ${this.config.clientId}`
    );
  }
}

// ---------------------------------------------------------------------------
// Factory (T010)
// ---------------------------------------------------------------------------

/**
 * Create the appropriate auth strategy based on config and stored state.
 *
 * Detection priority follows the public CLI contract:
 * 1. client_secret present → ClientCredentialsStrategy
 * 2. client_secret absent → PerUserAuthStrategy
 *
 * Stored per-user tokens are only consulted after authorization_code mode
 * has been selected.
 */
export function createAuthStrategy(
  config: AuthConfig,
  logger: BridgeLogger,
  options: CreateAuthStrategyOptions = {},
): AuthStrategy {
  const mode = detectAuthMode(config);
  if (mode === "client_credentials") {
    // ClientCredentialsStrategy expects BridgeConfig (with required clientSecret).
    const bridgeConfig: BridgeConfig = {
      instanceUrl: config.instanceUrl,
      clientId: config.clientId,
      clientSecret: config.clientSecret!,
      endpoint: config.endpoint,
      logLevel: config.logLevel,
      authTimeoutMs: config.authTimeoutMs,
    };
    return new ClientCredentialsStrategy(bridgeConfig, logger);
  }

  // Load tokens once and forward the result to avoid a second disk read
  // inside the PerUserAuthStrategy constructor.
  const stored = loadTokens(config.instanceUrl, config.clientId);

  if (stored.status === "loaded") {
    // Valid stored per-user tokens → always use per-user auth strategy.
    logger.debug("Found stored per-user tokens — using per-user auth strategy");
    return new PerUserAuthStrategy(config, logger, {
      allowInteractiveLogin: options.allowInteractiveLogin,
      loginHandler: options.loginHandler,
      preloadedTokens: stored,
    });
  }

  // No stored tokens, client_secret absent → per-user auth.
  // Pass the already-loaded result so the constructor doesn't read again.
  return new PerUserAuthStrategy(config, logger, {
    allowInteractiveLogin: options.allowInteractiveLogin,
    loginHandler: options.loginHandler,
    preloadedTokens: stored,
  });
}
