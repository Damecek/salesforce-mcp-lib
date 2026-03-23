import { CliUsageError } from "./errors.js";
import type { AppConfig, CliArgs } from "./types.js";

const MCP_PATH_PATTERN = /^\/services\/apexrest(?:\/[A-Za-z0-9._~!$&'()*+,;=:@-]+)+(?:\/)?$/;

export function parseCliArgs(argv: string[]): CliArgs {
  const args: CliArgs = {};

  for (let index = 0; index < argv.length; index += 1) {
    const current = argv[index];
    const next = argv[index + 1];

    switch (current) {
      case "--url":
        args.url = requireValue(current, next);
        index += 1;
        break;
      case "--client-id":
        args.clientId = requireValue(current, next);
        index += 1;
        break;
      case "--client-secret":
        args.clientSecret = requireValue(current, next);
        index += 1;
        break;
      case "--scope":
        args.scope = requireValue(current, next);
        index += 1;
        break;
      default:
        throw new CliUsageError(`Unknown argument: ${current}`);
    }
  }

  return args;
}

export function resolveConfig(argv: string[], env: NodeJS.ProcessEnv): AppConfig {
  const args = parseCliArgs(argv);
  const serverUrl = parseServerUrl(args.url);
  const clientId = normalizeValue(args.clientId ?? env.SF_CLIENT_ID);
  const clientSecret = normalizeValue(args.clientSecret ?? env.SF_CLIENT_SECRET);
  const scope = normalizeValue(args.scope ?? env.SF_SCOPE);

  if (!clientId) {
    throw new CliUsageError("Missing Salesforce client id. Use --client-id or SF_CLIENT_ID.");
  }

  if (!clientSecret) {
    throw new CliUsageError("Missing Salesforce client secret. Use --client-secret or SF_CLIENT_SECRET.");
  }

  return {
    serverUrl,
    tokenUrl: deriveTokenUrl(serverUrl),
    clientId,
    clientSecret,
    scope
  };
}

export function parseServerUrl(rawValue?: string): URL {
  const normalized = normalizeValue(rawValue);
  if (!normalized) {
    throw new CliUsageError("Missing --url. Provide a full Salesforce MCP endpoint URL.");
  }

  let parsed: URL;
  try {
    parsed = new URL(normalized);
  } catch {
    throw new CliUsageError("The --url value must be a valid HTTPS URL.");
  }

  if (parsed.protocol !== "https:") {
    throw new CliUsageError("The --url value must use HTTPS.");
  }

  if (parsed.username || parsed.password || parsed.search || parsed.hash) {
    throw new CliUsageError("The --url value must not include credentials, query parameters, or fragments.");
  }

  if (!MCP_PATH_PATTERN.test(parsed.pathname)) {
    throw new CliUsageError("The --url value must point to a Salesforce Apex REST MCP endpoint under /services/apexrest/.");
  }

  return parsed;
}

export function deriveTokenUrl(serverUrl: URL): URL {
  return new URL("/services/oauth2/token", serverUrl.origin);
}

function requireValue(flag: string, value: string | undefined): string {
  if (!value || value.startsWith("--")) {
    throw new CliUsageError(`Missing value for ${flag}.`);
  }
  return value;
}

function normalizeValue(value: string | undefined): string | undefined {
  const trimmed = value?.trim();
  return trimmed ? trimmed : undefined;
}
