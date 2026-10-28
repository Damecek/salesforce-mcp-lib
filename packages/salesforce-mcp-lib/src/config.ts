/**
 * CLI argument and environment-variable parser.
 * T035 — zero-dependency config resolution (process.argv + process.env).
 * T003 — per-user auth: optional clientSecret, headless, callbackPort, login subcommand.
 */

import process from 'node:process';
import type { AuthConfig } from './types.js';
import { assertSecureTransport } from './urlPolicy.js';

/** Map from CLI flag name to AuthConfig property name. */
const FLAG_MAP: Record<string, keyof AuthConfig> = {
  '--instance-url': 'instanceUrl',
  '--client-id': 'clientId',
  '--client-secret': 'clientSecret',
  '--endpoint': 'endpoint',
  '--sf-endpoint': 'endpoint', // alias — preferred in MCP client configs
  '--log-level': 'logLevel',
  '--headless': 'headless',
  '--callback-port': 'callbackPort',
  '--request-timeout-ms': 'requestTimeoutMs',
  '--max-concurrency': 'maxConcurrency',
};

/** Map from env-var name to AuthConfig property name. */
const ENV_MAP: Record<string, keyof AuthConfig> = {
  SF_INSTANCE_URL: 'instanceUrl',
  SF_CLIENT_ID: 'clientId',
  SF_CLIENT_SECRET: 'clientSecret',
  SF_ENDPOINT: 'endpoint',
  SF_LOG_LEVEL: 'logLevel',
  SF_HEADLESS: 'headless',
  SF_CALLBACK_PORT: 'callbackPort',
  SF_REQUEST_TIMEOUT_MS: 'requestTimeoutMs',
  SF_MAX_CONCURRENCY: 'maxConcurrency',
};

/** Numeric keys parsed strictly (digits only); invalid input becomes NaN and fails validation. */
const STRICT_INT_KEYS = new Set<keyof AuthConfig>(['requestTimeoutMs', 'maxConcurrency']);

function parseStrictInt(value: string): number {
  return /^\d+$/.test(value) ? Number(value) : NaN;
}

/** Boolean flags that don't take a value argument. */
const BOOLEAN_FLAGS = new Set<keyof AuthConfig>(['headless']);

/** Required config keys for MCP server mode — clientSecret is no longer required. */
const REQUIRED_KEYS: ReadonlyArray<keyof AuthConfig> = [
  'instanceUrl',
  'clientId',
  'endpoint',
];

/** Required config keys for login subcommand — only instanceUrl and clientId. */
const LOGIN_REQUIRED_KEYS: ReadonlyArray<keyof AuthConfig> = [
  'instanceUrl',
  'clientId',
];

function printUsage(): void {
  process.stderr.write(
    `Usage: salesforce-mcp-lib [options]
       salesforce-mcp-lib login [options]

Client Credentials Mode (--client-secret provided):
  Existing behavior. Authenticates as a service account using client_id + client_secret.

Per-User Auth Mode (--client-secret omitted):
  Authenticates as an individual Salesforce user via browser-based OAuth.
  Run 'salesforce-mcp-lib login' first to authenticate, then start the server.

MCP Server Options:
  --instance-url   / SF_INSTANCE_URL    Salesforce instance URL (required)
  --client-id      / SF_CLIENT_ID       External Client App consumer key (required)
  --client-secret  / SF_CLIENT_SECRET   External Client App consumer secret (optional)
  --endpoint       / SF_ENDPOINT        Apex REST endpoint path (required)
  --log-level      / SF_LOG_LEVEL       Log level (debug|info|warn|error) [default: info]
  --callback-port  / SF_CALLBACK_PORT   OAuth callback port [default: 13338]
  --request-timeout-ms / SF_REQUEST_TIMEOUT_MS
                                        Deadline per forwarded request in ms, covering
                                        authentication and retry (1000-600000) [default: 120000]
  --max-concurrency / SF_MAX_CONCURRENCY
                                        Concurrent requests to Salesforce (1-25) [default: 4]

Login Subcommand Options:
  --instance-url   / SF_INSTANCE_URL    Salesforce instance URL (required)
  --client-id      / SF_CLIENT_ID       External Client App consumer key (required)
  --headless       / SF_HEADLESS        Print URL instead of opening browser
  --callback-port  / SF_CALLBACK_PORT   OAuth callback port [default: 13338]
  --log-level      / SF_LOG_LEVEL       Log level [default: info]
`
  );
}

/**
 * Check whether the CLI invocation is the 'login' subcommand.
 * Returns true if process.argv[2] === 'login'.
 */
export function isLoginSubcommand(): boolean {
  return process.argv[2] === 'login';
}

/**
 * Parse raw CLI args and env vars into a partial AuthConfig.
 * Shared parsing logic used by both parseConfig and parseLoginConfig.
 */
function parseRaw(): Partial<AuthConfig> {
  const partial: Partial<AuthConfig> = {};

  // 1. Seed from environment variables (lowest precedence).
  for (const [envKey, configKey] of Object.entries(ENV_MAP)) {
    const value = process.env[envKey];
    if (value !== undefined && value !== '') {
      if (BOOLEAN_FLAGS.has(configKey)) {
        (partial as Record<string, unknown>)[configKey] =
          value === 'true' || value === '1';
      } else if (configKey === 'callbackPort') {
        (partial as Record<string, unknown>)[configKey] = parseInt(value, 10);
      } else if (STRICT_INT_KEYS.has(configKey)) {
        (partial as Record<string, unknown>)[configKey] = parseStrictInt(value);
      } else {
        (partial as Record<string, unknown>)[configKey] = value;
      }
    }
  }

  // 2. Override with CLI flags (highest precedence).
  // Skip 'login' subcommand if present.
  const startIdx = isLoginSubcommand() ? 3 : 2;
  const args = process.argv.slice(startIdx);
  for (let i = 0; i < args.length; i++) {
    const flag = args[i];
    const configKey = FLAG_MAP[flag];
    if (configKey !== undefined) {
      if (BOOLEAN_FLAGS.has(configKey)) {
        // Boolean flag — no value argument needed.
        (partial as Record<string, unknown>)[configKey] = true;
      } else {
        const value = args[i + 1];
        if (value === undefined || value.startsWith('--')) {
          process.stderr.write(`Error: flag ${flag} requires a value\n\n`);
          printUsage();
          process.exit(1);
        }
        if (configKey === 'callbackPort') {
          (partial as Record<string, unknown>)[configKey] = parseInt(
            value,
            10
          );
        } else if (STRICT_INT_KEYS.has(configKey)) {
          (partial as Record<string, unknown>)[configKey] = parseStrictInt(value);
        } else {
          (partial as Record<string, unknown>)[configKey] = value;
        }
        i++; // skip the value token
      }
    }
  }

  // 3. Validate values that were provided.
  if (partial.instanceUrl) {
    let parsedUrl: URL | undefined;
    try {
      parsedUrl = new URL(partial.instanceUrl);
    } catch {
      process.stderr.write(
        `Error: --instance-url is not a valid URL\n`
      );
      process.exit(1);
    }
    if (parsedUrl) {
      try {
        assertSecureTransport(parsedUrl, '--instance-url');
      } catch (err: unknown) {
        // The message never contains the URL, so credentials in it are not echoed.
        process.stderr.write(`Error: ${(err as Error).message}\n`);
        process.exit(1);
      }
    }
  }

  if (partial.endpoint && !/^\/(?!\/)/.test(partial.endpoint)) {
    process.stderr.write(
      `Error: --endpoint must be a path starting with a single "/" (for example /services/apexrest/mcp)\n`
    );
    process.exit(1);
  }

  if (
    partial.requestTimeoutMs !== undefined &&
    !(partial.requestTimeoutMs >= 1000 && partial.requestTimeoutMs <= 600000)
  ) {
    process.stderr.write(
      `Error: --request-timeout-ms must be an integer between 1000 and 600000\n`
    );
    process.exit(1);
  }

  if (
    partial.maxConcurrency !== undefined &&
    !(partial.maxConcurrency >= 1 && partial.maxConcurrency <= 25)
  ) {
    process.stderr.write(
      `Error: --max-concurrency must be an integer between 1 and 25\n`
    );
    process.exit(1);
  }

  if (partial.callbackPort !== undefined) {
    if (
      Number.isNaN(partial.callbackPort) ||
      partial.callbackPort < 1024 ||
      partial.callbackPort > 65535
    ) {
      process.stderr.write(
        `Error: --callback-port must be an integer between 1024 and 65535\n`
      );
      process.exit(1);
    }
  }

  const VALID_LOG_LEVELS = ['debug', 'info', 'warn', 'error'];
  if (
    partial.logLevel !== undefined &&
    !VALID_LOG_LEVELS.includes(partial.logLevel)
  ) {
    process.stderr.write(
      `Error: --log-level must be one of: ${VALID_LOG_LEVELS.join(', ')}\n`
    );
    process.exit(1);
  }

  return partial;
}

/**
 * Parse CLI args and env vars into a validated AuthConfig for MCP server mode.
 * CLI flags take precedence over env vars.
 *
 * Exits the process with code 1 and a usage message on stderr when any
 * required parameter is missing.
 */
export function parseConfig(): AuthConfig {
  const partial = parseRaw();

  // Validate required keys.
  const missing = REQUIRED_KEYS.filter(
    (k) => !(partial as Record<string, unknown>)[k]
  );
  if (missing.length > 0) {
    process.stderr.write(
      `Error: missing required configuration: ${missing.join(', ')}\n\n`
    );
    printUsage();
    process.exit(1);
  }

  return {
    instanceUrl: partial.instanceUrl!,
    clientId: partial.clientId!,
    clientSecret: partial.clientSecret,
    endpoint: partial.endpoint!,
    logLevel: partial.logLevel ?? 'info',
    headless: partial.headless ?? false,
    callbackPort: partial.callbackPort ?? 13338,
    requestTimeoutMs: partial.requestTimeoutMs ?? 120000,
    maxConcurrency: partial.maxConcurrency ?? 4,
  };
}

/**
 * Parse CLI args and env vars for the login subcommand.
 * Only instanceUrl and clientId are required (no endpoint or clientSecret).
 *
 * Exits the process with code 1 on missing params.
 */
export function parseLoginConfig(): AuthConfig {
  const partial = parseRaw();

  // Validate login-specific required keys.
  const missing = LOGIN_REQUIRED_KEYS.filter(
    (k) => !(partial as Record<string, unknown>)[k]
  );
  if (missing.length > 0) {
    process.stderr.write(
      `Error: missing required configuration: ${missing.join(', ')}\n\n`
    );
    printUsage();
    process.exit(1);
  }

  return {
    instanceUrl: partial.instanceUrl!,
    clientId: partial.clientId!,
    clientSecret: partial.clientSecret,
    endpoint: partial.endpoint ?? '',
    logLevel: partial.logLevel ?? 'info',
    headless: partial.headless ?? false,
    callbackPort: partial.callbackPort ?? 13338,
  };
}
