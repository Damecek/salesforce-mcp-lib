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
  PerUserTokenData,
} from './types.js';
import type { BridgeLogger } from './mcpBridge.js';
import { ClientCredentialsStrategy } from './oauth.js';
import { performLogin, refreshAccessToken } from './perUserAuth.js';
import { loadTokens, saveTokens, deleteTokens } from './tokenStore.js';
import type { LoadTokensResult } from './tokenStore.js';
import { LoginRequiredError, SessionExpiredError } from './errors.js';
import type { BridgeConfig } from './types.js';

/** Abstract authentication strategy. Both flows implement this. */
export interface AuthStrategy {
  /** Get a valid access token. May trigger login or refresh. */
  getAccessToken(): Promise<string>;
  /** Get the Salesforce instance URL. */
  getInstanceUrl(): string | null;
  /** Attempt to re-authenticate (called on 401). */
  reauthenticate(): Promise<OAuthTokenResponse>;
  /** The auth mode this strategy implements. */
  readonly mode: AuthMode;
}

/**
 * Detect auth mode from config without creating a strategy.
 * client_secret present → client_credentials; absent → authorization_code.
 */
export function detectAuthMode(config: AuthConfig): AuthMode {
  return config.clientSecret ? 'client_credentials' : 'authorization_code';
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

// ---------------------------------------------------------------------------
// PerUserAuthStrategy (T010 + T015)
// ---------------------------------------------------------------------------

/**
 * AuthStrategy implementation for OAuth 2.0 Authorization Code flow with PKCE.
 * Manages cached tokens, refresh, and persistence.
 */
export class PerUserAuthStrategy implements AuthStrategy {
  readonly mode = 'authorization_code' as const;
  private readonly config: AuthConfig;
  private readonly logger: BridgeLogger;
  private readonly allowInteractiveLogin: boolean;
  private readonly loginHandler: typeof performLogin;
  private cachedToken: string | null = null;
  private cachedInstanceUrl: string | null = null;
  private cachedRefreshToken: string | null = null;
  private _tokensLoaded = false;

  constructor(
    config: AuthConfig,
    logger: BridgeLogger,
    options: PerUserAuthStrategyOptions = {}
  ) {
    this.config = config;
    this.logger = logger;
    this.allowInteractiveLogin = options.allowInteractiveLogin ?? true;
    this.loginHandler = options.loginHandler ?? performLogin;

    // T015: Load stored tokens, using a pre-loaded result when provided
    // (avoids a redundant disk read when called from createAuthStrategy).
    const result =
      options.preloadedTokens ?? loadTokens(config.instanceUrl, config.clientId);
    this.applyLoadResult(result);
  }

  /** Whether stored tokens were found during construction. */
  get tokensLoaded(): boolean {
    return this._tokensLoaded;
  }

  private applyLoadResult(result: LoadTokensResult): void {
    switch (result.status) {
      case 'loaded':
        this.cachedToken = result.data.accessToken;
        this.cachedInstanceUrl = result.data.instanceUrl;
        this.cachedRefreshToken = result.data.refreshToken;
        this._tokensLoaded = true;
        this.logger.info(`Loaded stored tokens for ${this.config.instanceUrl}`);
        break;
      case 'corrupt':
        this.logger.warn(
          `Stored token file is corrupt (${result.reason}) — ignoring. ` +
            `Run "salesforce-mcp-lib login" to re-authenticate.`
        );
        deleteTokens(this.config.instanceUrl, this.config.clientId);
        break;
      case 'error':
        this.logger.warn(
          `Could not read stored tokens: ${result.error.message}`
        );
        break;
      case 'missing':
        this.logger.info('No stored credentials found');
        break;
    }
  }

  async getAccessToken(): Promise<string> {
    // Return cached token if available.
    if (this.cachedToken) {
      return this.cachedToken;
    }

    // Try to refresh if we have a refresh token.
    if (this.cachedRefreshToken) {
      try {
        this.logger.info('Refreshing access token...');
        const response = await refreshAccessToken(
          this.config.instanceUrl,
          this.config.clientId,
          this.cachedRefreshToken,
          this.config.clientSecret
        );
        this.updateCachedTokens(response);
        this.logger.info(
          `Token refreshed successfully (identity: ${response.id})`
        );
        return response.access_token;
      } catch (err) {
        if (err instanceof SessionExpiredError) {
          // Refresh token is invalid — fall through to interactive login.
          this.logger.warn(
            'Refresh token expired or revoked — stored tokens cleared, will re-login'
          );
          deleteTokens(this.config.instanceUrl, this.config.clientId);
          this.clearCache();
          if (!this.allowInteractiveLogin) {
            throw new LoginRequiredError(this.buildLoginRequiredMessage());
          }
        } else if (!this.allowInteractiveLogin) {
          throw err;
        }
        // Other errors — try login.
        this.logger.warn(
          `Token refresh failed: ${err instanceof Error ? err.message : String(err)}`
        );
      }
    }

    // No cached token and no refresh token — perform interactive login.
    // Opens browser for OAuth, waits for callback. Does not require stdin.
    if (!this.allowInteractiveLogin) {
      throw new LoginRequiredError(this.buildLoginRequiredMessage());
    }
    this.logger.info('No stored credentials — starting browser login flow...');
    const response = await this.loginHandler(this.config, this.logger);
    this.updateCachedTokens(response);
    return response.access_token;
  }

  getInstanceUrl(): string | null {
    return this.cachedInstanceUrl ?? this.config.instanceUrl;
  }

  async reauthenticate(): Promise<OAuthTokenResponse> {
    // T015: Try refresh first, fall back to full login.
    if (this.cachedRefreshToken) {
      try {
        this.logger.info('Attempting token refresh for re-authentication...');
        const response = await refreshAccessToken(
          this.config.instanceUrl,
          this.config.clientId,
          this.cachedRefreshToken,
          this.config.clientSecret
        );
        this.updateCachedTokens(response);
        this.logger.info('Re-authentication via refresh succeeded');
        return response;
      } catch (err) {
        this.logger.warn(
          `Refresh failed during re-auth: ${err instanceof Error ? err.message : String(err)}`
        );
        // T025: Clear stored tokens on refresh failure (mid-session deactivation).
        if (err instanceof SessionExpiredError) {
          deleteTokens(this.config.instanceUrl, this.config.clientId);
          this.clearCache();
          if (!this.allowInteractiveLogin) {
            throw new SessionExpiredError(this.buildSessionExpiredMessage());
          }
        } else if (!this.allowInteractiveLogin) {
          throw err;
        }
      }
    }

    // Fall back to full login.
    if (!this.allowInteractiveLogin) {
      throw new SessionExpiredError(this.buildSessionExpiredMessage());
    }
    this.logger.info('Performing full re-authentication via login flow...');
    const response = await this.loginHandler(this.config, this.logger);
    this.updateCachedTokens(response);
    return response;
  }

  private updateCachedTokens(response: OAuthTokenResponse): void {
    this.cachedToken = response.access_token;
    this.cachedInstanceUrl = response.instance_url;

    // Build persisted token data.
    const tokenData: PerUserTokenData = {
      accessToken: response.access_token,
      refreshToken: response.refresh_token ?? this.cachedRefreshToken ?? '',
      instanceUrl: response.instance_url,
      tokenType: response.token_type,
      issuedAt: parseInt(response.issued_at, 10) || Date.now(),
      identityUrl: response.id,
    };

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

  /** Clear all cached token state. */
  invalidateToken(): void {
    this.cachedToken = null;
  }

  private clearCache(): void {
    this.cachedToken = null;
    this.cachedInstanceUrl = null;
    this.cachedRefreshToken = null;
    this._tokensLoaded = false;
  }

  private buildLoginRequiredMessage(): string {
    return (
      'No stored credentials found. Please log in first: ' +
      this.buildLoginCommand()
    );
  }

  private buildSessionExpiredMessage(): string {
    return (
      'Your session has expired and cannot be refreshed. Please log in again: ' +
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
 * Detection priority:
 * 1. Stored per-user tokens exist → PerUserAuthStrategy (even if client_secret is in config)
 * 2. client_secret present, no stored tokens → ClientCredentialsStrategy
 * 3. No client_secret, no stored tokens → PerUserAuthStrategy
 *
 * This allows a single Connected App to support both flows — the user can
 * provide client_secret for the initial token exchange while still using
 * per-user identity via Authorization Code flow.
 */
export function createAuthStrategy(
  config: AuthConfig,
  logger: BridgeLogger,
  options: CreateAuthStrategyOptions = {}
): AuthStrategy {
  // Load tokens once and forward the result to avoid a second disk read
  // inside the PerUserAuthStrategy constructor.
  const stored = loadTokens(config.instanceUrl, config.clientId);

  if (stored.status === 'loaded') {
    // Valid stored per-user tokens → always use per-user auth strategy.
    logger.debug('Found stored per-user tokens — using per-user auth strategy');
    return new PerUserAuthStrategy(config, logger, {
      allowInteractiveLogin: options.allowInteractiveLogin,
      loginHandler: options.loginHandler,
      preloadedTokens: stored,
    });
  }

  const mode = detectAuthMode(config);
  if (mode === 'client_credentials') {
    // ClientCredentialsStrategy expects BridgeConfig (with required clientSecret).
    const bridgeConfig: BridgeConfig = {
      instanceUrl: config.instanceUrl,
      clientId: config.clientId,
      clientSecret: config.clientSecret!,
      endpoint: config.endpoint,
      logLevel: config.logLevel,
    };
    return new ClientCredentialsStrategy(bridgeConfig, logger);
  }

  // No stored tokens, no client_secret → per-user auth.
  // Pass the already-loaded result so the constructor doesn't read again.
  return new PerUserAuthStrategy(config, logger, {
    allowInteractiveLogin: options.allowInteractiveLogin,
    loginHandler: options.loginHandler,
    preloadedTokens: stored,
  });
}
