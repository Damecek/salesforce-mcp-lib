/**
 * CLI argument and environment-variable parser.
 * T035 — zero-dependency config resolution (process.argv + process.env).
 */

import process from 'node:process';
import type { BridgeConfig } from './types.js';

/** Map from CLI flag name to BridgeConfig property name. */
const FLAG_MAP: Record<string, keyof BridgeConfig> = {
  '--instance-url': 'instanceUrl',
  '--client-id': 'clientId',
  '--client-secret': 'clientSecret',
  '--endpoint': 'endpoint',
  '--log-level': 'logLevel',
};

/** Map from env-var name to BridgeConfig property name. */
const ENV_MAP: Record<string, keyof BridgeConfig> = {
  SF_INSTANCE_URL: 'instanceUrl',
  SF_CLIENT_ID: 'clientId',
  SF_CLIENT_SECRET: 'clientSecret',
  SF_ENDPOINT: 'endpoint',
  SF_LOG_LEVEL: 'logLevel',
};

/** Required config keys — missing any of these is fatal. */
const REQUIRED_KEYS: ReadonlyArray<keyof BridgeConfig> = [
  'instanceUrl',
  'clientId',
  'clientSecret',
  'endpoint',
];

function printUsage(): void {
  process.stderr.write(
    `Usage: salesforce-mcp-lib [options]

Required (CLI flags override environment variables):
  --instance-url   / SF_INSTANCE_URL    Salesforce instance URL
  --client-id      / SF_CLIENT_ID       Connected-app consumer key
  --client-secret  / SF_CLIENT_SECRET   Connected-app consumer secret
  --endpoint       / SF_ENDPOINT        Apex REST endpoint path

Optional:
  --log-level      / SF_LOG_LEVEL       Log level (debug|info|warn|error) [default: info]
`
  );
}

/**
 * Parse CLI args (process.argv) and environment variables into a
 * validated BridgeConfig. CLI flags take precedence over env vars.
 *
 * Exits the process with code 1 and a usage message on stderr when any
 * required parameter is missing.
 */
export function parseConfig(): BridgeConfig {
  const partial: Partial<BridgeConfig> = {};

  // 1. Seed from environment variables (lowest precedence).
  for (const [envKey, configKey] of Object.entries(ENV_MAP)) {
    const value = process.env[envKey];
    if (value !== undefined && value !== '') {
      partial[configKey] = value;
    }
  }

  // 2. Override with CLI flags (highest precedence).
  const args = process.argv.slice(2);
  for (let i = 0; i < args.length; i++) {
    const flag = args[i];
    const configKey = FLAG_MAP[flag];
    if (configKey !== undefined) {
      const value = args[i + 1];
      if (value === undefined || value.startsWith('--')) {
        process.stderr.write(`Error: flag ${flag} requires a value\n\n`);
        printUsage();
        process.exit(1);
      }
      partial[configKey] = value;
      i++; // skip the value token
    }
  }

  // 3. Validate required keys.
  const missing = REQUIRED_KEYS.filter((k) => !partial[k]);
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
    clientSecret: partial.clientSecret!,
    endpoint: partial.endpoint!,
    logLevel: partial.logLevel ?? 'info',
  };
}
