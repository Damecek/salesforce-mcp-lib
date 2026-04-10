#!/usr/bin/env node
/**
 * CLI entry point for salesforce-mcp-lib.
 * T039 — orchestrates config, auth, bridge, and stdio transport.
 * T058 — hardened startup auth: token validation, secret redaction, clear errors.
 */

import process from 'node:process';
import { parseConfig } from './config.js';
import { authenticate } from './oauth.js';
import { createBridge } from './mcpBridge.js';
import { createLogger, startStdioListener } from './stdio.js';

/**
 * Redact known secrets from a string so they never appear in logs.
 * Replaces any occurrence of the client_secret value with "****".
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

async function main(): Promise<void> {
  // 1. Parse configuration (exits on missing params).
  const config = parseConfig();

  // Secrets that must never appear in log output.
  const secrets = [config.clientSecret];

  // 2. Create logger that automatically redacts secrets.
  const rawLogger = createLogger(config.logLevel ?? 'info');
  const logger = {
    debug: (msg: string) => rawLogger.debug(redactSecrets(msg, secrets)),
    info: (msg: string) => rawLogger.info(redactSecrets(msg, secrets)),
    warn: (msg: string) => rawLogger.warn(redactSecrets(msg, secrets)),
    error: (msg: string) => rawLogger.error(redactSecrets(msg, secrets)),
  };

  // Log startup info — secrets are redacted by the wrapper above.
  logger.info('salesforce-mcp-lib starting');
  logger.info(`  instance-url : ${config.instanceUrl}`);
  logger.info(`  client-id    : ${config.clientId.slice(0, 8)}...(redacted)`);
  logger.info('  client-secret: ****(redacted)');
  logger.info(`  endpoint     : ${config.endpoint}`);
  logger.info(`  log-level    : ${config.logLevel ?? 'info'}`);

  // 3. Authenticate and validate the token.
  try {
    const tokenResponse = await authenticate(config);

    // Validate the token structure: must be a non-empty string with
    // reasonable length (Salesforce access tokens are typically 100+ chars).
    if (
      !tokenResponse.access_token ||
      tokenResponse.access_token.length < 20
    ) {
      throw new Error(
        'OAuth token validation failed: received token is malformed or too short'
      );
    }

    // Validate instance_url is a parseable URL.
    try {
      new URL(tokenResponse.instance_url);
    } catch {
      throw new Error(
        `OAuth token validation failed: instance_url is not a valid URL: ${tokenResponse.instance_url}`
      );
    }

    logger.info(
      `Authenticated successfully (instance: ${tokenResponse.instance_url})`
    );
    logger.info(
      `Token validated: type=${tokenResponse.token_type}, length=${tokenResponse.access_token.length}`
    );
  } catch (err: unknown) {
    const rawMsg = err instanceof Error ? err.message : String(err);
    const safeMsg = redactSecrets(rawMsg, secrets);
    logger.error(`Authentication failed: ${safeMsg}`);
    logger.error(
      'Startup aborted — check instance URL, client credentials, and External Client App configuration'
    );
    process.exit(1);
  }

  // 4. Create bridge with the redacting logger for re-auth warnings.
  const bridge = createBridge(config, logger);

  // 5. Start stdio listener — forward every inbound message through the bridge.
  logger.info('Listening on stdin for JSON-RPC messages');
  startStdioListener((message) => bridge.forward(message), logger);
}

main().catch((err: unknown) => {
  const msg = err instanceof Error ? err.message : String(err);
  process.stderr.write(`Fatal: ${msg}\n`);
  process.exit(1);
});
