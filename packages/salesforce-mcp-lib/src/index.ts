#!/usr/bin/env node
/**
 * CLI entry point for salesforce-mcp-lib.
 * T039 — orchestrates config, auth, bridge, and stdio transport.
 * T058 — hardened startup auth: token validation, secret redaction, clear errors.
 * T012 — login subcommand routing, auth mode detection.
 * T016 — per-user mode: stored token loading, refresh logging.
 * T018 — client credentials: auth-mode logging, backward-compatible startup.
 * T023 — specific error subclass handling with actionable stderr messages.
 * T024 — refresh_token added to secrets list for redaction.
 */

import process from 'node:process';
import { parseConfig, parseLoginConfig, isLoginSubcommand } from './config.js';
import { createBridge } from './mcpBridge.js';
import { createLogger, startStdioListener } from './stdio.js';
import {
  createAuthStrategy,
  PerUserAuthStrategy,
} from './authStrategy.js';
import { performLogin } from './perUserAuth.js';
import { saveTokens } from './tokenStore.js';
import type { PerUserTokenData } from './types.js';
import {
  InvalidCredentialsError,
  InsufficientAccessError,
  ConnectivityError,
  ConsentDeniedError,
  LoginRequiredError,
  SessionExpiredError,
} from './errors.js';

/**
 * Redact known secrets from a string so they never appear in logs.
 * Replaces any occurrence of secret values with "****".
 */
export function redactSecrets(text: string, secrets: string[]): string {
  let redacted = text;
  for (const secret of secrets) {
    if (secret.length > 0) {
      redacted = redacted.replaceAll(secret, '****');
    }
  }
  return redacted;
}

// ---------------------------------------------------------------------------
// Login subcommand (T012)
// ---------------------------------------------------------------------------

async function runLogin(): Promise<void> {
  const config = parseLoginConfig();

  const rawLogger = createLogger(config.logLevel ?? 'info');
  const loginSecrets: string[] = [];
  if (config.clientSecret) loginSecrets.push(config.clientSecret);
  const logger = {
    debug: (msg: string) => rawLogger.debug(redactSecrets(msg, loginSecrets)),
    info: (msg: string) => rawLogger.info(redactSecrets(msg, loginSecrets)),
    warn: (msg: string) => rawLogger.warn(redactSecrets(msg, loginSecrets)),
    error: (msg: string) => rawLogger.error(redactSecrets(msg, loginSecrets)),
  };

  logger.info('salesforce-mcp-lib login');
  logger.info(`  instance-url : ${config.instanceUrl}`);
  logger.info(
    `  client-id    : ${config.clientId.slice(0, 8)}...(redacted)`
  );
  if (config.clientSecret) {
    logger.info('  client-secret: ****(redacted)');
  }
  logger.info(`  headless     : ${config.headless ?? false}`);
  logger.info(`  callback-port: ${config.callbackPort ?? 13338}`);

  try {
    const tokenResponse = await performLogin(config, logger);

    // S3: Add returned tokens to secrets list so they are never logged.
    if (tokenResponse.access_token) {
      loginSecrets.push(tokenResponse.access_token);
    }
    if (tokenResponse.refresh_token) {
      loginSecrets.push(tokenResponse.refresh_token);
    }

    // Build persisted token data.
    const tokenData: PerUserTokenData = {
      accessToken: tokenResponse.access_token,
      refreshToken: tokenResponse.refresh_token ?? '',
      instanceUrl: tokenResponse.instance_url,
      tokenType: tokenResponse.token_type,
      issuedAt: parseInt(tokenResponse.issued_at, 10) || Date.now(),
      identityUrl: tokenResponse.id,
    };

    // Persist tokens.
    saveTokens(config.instanceUrl, config.clientId, tokenData);

    const host = new URL(config.instanceUrl).hostname;
    logger.info(`Login successful! Tokens stored for ${host}`);
    if (tokenResponse.id) {
      logger.info(`User: ${tokenResponse.id}`);
    }

    process.exit(0);
  } catch (err: unknown) {
    // T023: Specific error handling with actionable messages.
    if (err instanceof InvalidCredentialsError) {
      logger.error(
        `Authentication failed: credentials rejected. Verify client_id or run login again.`
      );
      process.exit(2);
    }
    if (err instanceof InsufficientAccessError) {
      logger.error(
        `Authentication failed: user lacks Connected App access. Contact your Salesforce administrator.`
      );
      process.exit(2);
    }
    if (err instanceof ConsentDeniedError) {
      logger.error(
        `Authentication failed: consent required. Please retry login and click "Allow".`
      );
      process.exit(2);
    }
    if (err instanceof ConnectivityError) {
      logger.error(
        `Authentication failed: cannot reach ${config.instanceUrl}. Check your network connection and instance URL.`
      );
      process.exit(2);
    }

    const rawMsg = err instanceof Error ? err.message : String(err);

    // Check for timeout.
    if (rawMsg.includes('timed out') || rawMsg.includes('timeout')) {
      logger.error(`Login timed out: ${rawMsg}`);
      process.exit(3);
    }

    logger.error(`Login failed: ${rawMsg}`);
    process.exit(2);
  }
}

// ---------------------------------------------------------------------------
// MCP server mode (T012 + T016 + T018)
// ---------------------------------------------------------------------------

async function runServer(): Promise<void> {
  // 1. Parse configuration (exits on missing params).
  const config = parseConfig();

  // Secrets that must never appear in log output.
  // T024: Include refresh_token if we have stored tokens.
  const secrets: string[] = [];
  if (config.clientSecret) {
    secrets.push(config.clientSecret);
  }

  // 2. Create logger that automatically redacts secrets.
  const rawLogger = createLogger(config.logLevel ?? 'info');
  const logger = {
    debug: (msg: string) => rawLogger.debug(redactSecrets(msg, secrets)),
    info: (msg: string) => rawLogger.info(redactSecrets(msg, secrets)),
    warn: (msg: string) => rawLogger.warn(redactSecrets(msg, secrets)),
    error: (msg: string) => rawLogger.error(redactSecrets(msg, secrets)),
  };

  // Log startup info.
  logger.info('salesforce-mcp-lib starting');
  logger.info(`  instance-url : ${config.instanceUrl}`);
  logger.info(
    `  client-id    : ${config.clientId.slice(0, 8)}...(redacted)`
  );
  if (config.clientSecret) {
    logger.info('  client-secret: ****(redacted)');
  }
  logger.info(`  endpoint     : ${config.endpoint}`);
  logger.info(`  log-level    : ${config.logLevel ?? 'info'}`);

  // 3. Create auth strategy (may detect stored per-user tokens).
  const strategy = createAuthStrategy(config, logger, {
    allowInteractiveLogin: false,
  });
  logger.info(`  auth-mode    : ${strategy.mode === 'client_credentials' ? 'client_credentials' : 'per-user (authorization code)'}`);

  // 4. Authenticate.
  try {
    const token = await strategy.getAccessToken();

    // T024: Add tokens to secrets list for redaction.
    secrets.push(token);
    if (strategy instanceof PerUserAuthStrategy) {
      const refreshToken = strategy.getRefreshToken();
      if (refreshToken) {
        secrets.push(refreshToken);
      }
    }

    // Validate the token structure.
    if (!token || token.length < 20) {
      throw new Error(
        'OAuth token validation failed: received token is malformed or too short'
      );
    }

    // Validate instance_url.
    const instanceUrl = strategy.getInstanceUrl();
    if (instanceUrl) {
      try {
        new URL(instanceUrl);
      } catch {
        throw new Error(
          `OAuth token validation failed: instance_url is not a valid URL: ${instanceUrl}`
        );
      }
    }

    logger.info(
      `Authenticated successfully (instance: ${instanceUrl ?? config.instanceUrl})`
    );
  } catch (err: unknown) {
    // T023: Specific error subclass handling.
    if (err instanceof LoginRequiredError) {
      logger.error(err.message);
      process.exit(2);
    }
    if (err instanceof SessionExpiredError) {
      logger.error(`Session expired: ${err.message}`);
      process.exit(2);
    }
    if (err instanceof InvalidCredentialsError) {
      logger.error(
        'Authentication failed: credentials rejected. Verify client_id and Connected App settings, or run login again.'
      );
      process.exit(2);
    }
    if (err instanceof InsufficientAccessError) {
      logger.error(
        'Authentication failed: user lacks Connected App access. Contact your Salesforce administrator.'
      );
      process.exit(2);
    }
    if (err instanceof ConnectivityError) {
      logger.error(
        `Authentication failed: cannot reach ${config.instanceUrl}. Check your network connection and instance URL.`
      );
      process.exit(2);
    }
    if (err instanceof ConsentDeniedError) {
      logger.error(
        'Authentication failed: consent required. Retry login and click "Allow".'
      );
      process.exit(2);
    }

    const rawMsg = err instanceof Error ? err.message : String(err);
    const safeMsg = redactSecrets(rawMsg, secrets);
    logger.error(`Authentication failed: ${safeMsg}`);
    logger.error(
      'Startup aborted — check instance URL, client credentials, and External Client App configuration'
    );
    process.exit(1);
  }

  // 5. Create bridge with the redacting logger.
  const bridge = createBridge(strategy, config, logger);

  // 6. Start stdio listener — forward every inbound message through the bridge.
  logger.info('Listening on stdin for JSON-RPC messages');
  startStdioListener((message) => bridge.forward(message), logger);
}

// ---------------------------------------------------------------------------
// Main routing
// ---------------------------------------------------------------------------

async function main(): Promise<void> {
  if (isLoginSubcommand()) {
    await runLogin();
  } else {
    await runServer();
  }
}

main().catch((err: unknown) => {
  const msg = err instanceof Error ? err.message : String(err);
  process.stderr.write(`Fatal: ${msg}\n`);
  process.exit(1);
});
