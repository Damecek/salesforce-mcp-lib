/**
 * Stdio transport — newline-delimited JSON-RPC over stdin/stdout.
 * T038 — readline listener and levelled stderr logger.
 */

import { createInterface } from 'node:readline';
import process from 'node:process';

// ---------------------------------------------------------------------------
// Logger
// ---------------------------------------------------------------------------

/** Supported log levels, ordered by severity. */
const LOG_LEVELS = ['debug', 'info', 'warn', 'error'] as const;
type LogLevel = (typeof LOG_LEVELS)[number];

/** Stderr logger with level filtering. */
export interface Logger {
  debug(message: string): void;
  info(message: string): void;
  warn(message: string): void;
  error(message: string): void;
}

function levelIndex(level: string): number {
  const idx = LOG_LEVELS.indexOf(level as LogLevel);
  return idx === -1 ? 1 : idx; // default to 'info' for unrecognised values
}

/**
 * Create a levelled logger that writes exclusively to stderr.
 *
 * @param level Minimum severity to emit (debug | info | warn | error).
 */
export function createLogger(level: string): Logger {
  const threshold = levelIndex(level);

  function write(severity: LogLevel, message: string): void {
    if (levelIndex(severity) >= threshold) {
      const ts = new Date().toISOString();
      process.stderr.write(`[${ts}] [${severity.toUpperCase()}] ${message}\n`);
    }
  }

  return {
    debug: (msg: string) => write('debug', msg),
    info: (msg: string) => write('info', msg),
    warn: (msg: string) => write('warn', msg),
    error: (msg: string) => write('error', msg),
  };
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Extract JSON-RPC metadata (id + method) for safe logging.
 * Avoids logging full message bodies which may contain sensitive data / PII.
 */
function summariseJsonRpc(raw: string): string {
  try {
    const msg = JSON.parse(raw) as Record<string, unknown>;
    const id = msg['id'] ?? null;
    const method = msg['method'] ?? (msg['error'] ? 'error' : 'response');
    return `{id:${JSON.stringify(id)}, method:${JSON.stringify(method)}}`;
  } catch {
    return `(non-JSON, ${raw.length} bytes)`;
  }
}

// ---------------------------------------------------------------------------
// Stdio listener
// ---------------------------------------------------------------------------

/**
 * Read newline-delimited JSON-RPC messages from stdin, forward each to
 * `onMessage`, and write the returned response (plus newline) to stdout.
 *
 * Empty lines are silently ignored.
 *
 * @param onMessage Async handler that receives a raw JSON string and returns
 *                  a raw JSON string response.
 * @param logger    Logger instance for operational messages.
 */
export function startStdioListener(
  onMessage: (message: string) => Promise<string>,
  logger: Logger
): void {
  const rl = createInterface({
    input: process.stdin,
    terminal: false,
  });

  rl.on('line', (line: string) => {
    const trimmed = line.trim();
    if (trimmed.length === 0) {
      return;
    }

    // Log only JSON-RPC metadata (id + method) to avoid leaking sensitive
    // business data or PII from Salesforce responses into debug logs.
    logger.debug(`stdin >> ${summariseJsonRpc(trimmed)}`);

    onMessage(trimmed)
      .then((response) => {
        logger.debug(`stdout << ${summariseJsonRpc(response)}`);
        process.stdout.write(response + '\n');
      })
      .catch((err: unknown) => {
        const errMessage =
          err instanceof Error ? err.message : String(err);
        logger.error(`Unhandled error processing message: ${errMessage}`);

        // Attempt to build a minimal JSON-RPC error so the client is not
        // left hanging.  We do not know the id so we send null.
        const fallback = JSON.stringify({
          jsonrpc: '2.0',
          id: null,
          error: {
            code: -32603,
            message: `Internal proxy error: ${errMessage}`,
          },
        });
        process.stdout.write(fallback + '\n');
      });
  });

  rl.on('close', () => {
    logger.info('stdin closed — shutting down');
    process.exit(0);
  });
}
