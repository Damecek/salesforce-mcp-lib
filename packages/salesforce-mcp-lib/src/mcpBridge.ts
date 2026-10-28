/**
 * MCP bridge — forwards JSON-RPC messages to a Salesforce Apex endpoint.
 * T037 — HTTP transport, 401 re-auth, and error translation.
 * T059 — hardened 401 re-auth: warn logging, sanitized client errors.
 * T011 — refactored to accept AuthStrategy instead of direct oauth.ts calls.
 * T022 — improved 401 handling with specific error subclasses.
 * v2 — classified messages, protocol headers, bounded exchange (spec C3).
 */

import https from 'node:https';
import http from 'node:http';
import { URL } from 'node:url';
import type { AuthConfig } from './types.js';
import { SalesforceAuthError, SessionExpiredError, ConnectivityError, InvalidCredentialsError } from './errors.js';
import type { AuthStrategy } from './authStrategy.js';
import { headersFromPlan, interpretRemote, localError, protocolError } from './protocol.js';
import type { ForwardableMessage, RemoteOutcome } from './protocol.js';
import { assertSecureTransport } from './urlPolicy.js';
import { safeRemoteText } from './redact.js';

/** Minimal logger interface accepted by the bridge. */
export interface BridgeLogger {
  debug(message: string): void;
  info(message: string): void;
  warn(message: string): void;
  error(message: string): void;
}

/** No-op logger used when none is provided. */
const nullLogger: BridgeLogger = {
  debug: () => {},
  info: () => {},
  warn: () => {},
  error: () => {},
};

/** What the stdio layer must do with a forwarded message. */
export type BridgeOutcome = { kind: 'write'; line: string } | { kind: 'silent' };

/** Represents the forward function returned by createBridge. */
export interface Bridge {
  /**
   * Forward one classified message. `signal` cancels the exchange; a
   * cancelled message always yields `silent`. The returned promise never
   * rejects: every failure becomes a bounded local error (requests) or a
   * logged warning (notifications).
   */
  forward(message: ForwardableMessage, signal?: AbortSignal): Promise<BridgeOutcome>;
}

export const DEFAULT_REQUEST_TIMEOUT_MS = 120_000;
/** Largest remote response body accepted (spec 7.3). */
export const MAX_RESPONSE_BYTES = 8 * 1024 * 1024;

class AbortedError extends Error {}
class ResponseTooLargeError extends Error {}

/** Log-safe error text: our own auth messages are bounded, anything else is reduced to its class name. */
function describeError(err: unknown): string {
  if (err instanceof SalesforceAuthError) return safeRemoteText(err.message);
  return err instanceof Error ? err.name : 'unknown error';
}

/**
 * Resolve the Apex endpoint URL the bearer token is sent to. The token must
 * never leave the instance origin and must travel over https (plain http only
 * for loopback test servers). No hostname allowlist: custom Salesforce
 * domains are valid.
 *
 * @throws Error with a message that never contains the URL.
 */
export function resolveTarget(instanceUrl: string, endpoint: string): URL {
  let base: URL;
  try {
    base = new URL(instanceUrl);
  } catch {
    throw new Error('instance URL is not a valid URL');
  }
  assertSecureTransport(base, 'instance URL');
  if (!/^\/(?!\/)/.test(endpoint) || endpoint.includes('\\')) {
    throw new Error('endpoint must be a path starting with a single "/"');
  }
  const target = new URL(endpoint, base);
  if (target.origin !== base.origin || target.username || target.password) {
    throw new Error('endpoint must stay on the instance origin');
  }
  return target;
}

/**
 * Create a bridge that forwards classified JSON-RPC messages to Salesforce.
 *
 * The bridge uses the provided AuthStrategy for token retrieval and
 * handles transparent 401 re-authentication (single retry). One deadline
 * (`config.requestTimeoutMs`) bounds authentication, retry and response.
 *
 * @param strategy Auth strategy for obtaining/refreshing tokens.
 * @param config Bridge configuration (instance URL, endpoint, timeout).
 * @param logger Optional logger for operational messages.
 */
export function createBridge(
  strategy: AuthStrategy,
  config: AuthConfig,
  logger?: BridgeLogger
): Bridge {
  const log = logger ?? nullLogger;
  const timeoutMs = config.requestTimeoutMs ?? DEFAULT_REQUEST_TIMEOUT_MS;
  const state: { legacyVersion: string | null } = { legacyVersion: null };

  /** One authenticated POST. Throws AbortedError / ResponseTooLargeError / network errors. */
  async function post(
    msg: ForwardableMessage,
    headers: Record<string, string>,
    instanceUrl: string,
    token: string,
    signal: AbortSignal
  ): Promise<HttpResult> {
    let target: URL;
    try {
      target = resolveTarget(instanceUrl, config.endpoint);
    } catch (err: unknown) {
      throw new LocalReject(`Refusing to send credentials: ${(err as Error).message}`);
    }
    return postJsonRpc(target, token, msg.raw, headers, signal);
  }

  async function exchange(msg: ForwardableMessage, signal: AbortSignal): Promise<BridgeOutcome> {
    const requestId = msg.kind === 'request' ? msg.id : undefined;
    const finish = (remote: RemoteOutcome): BridgeOutcome => {
      if (remote.kind === 'write') {
        if (msg.method === 'initialize') rememberLegacyVersion(remote.protocolVersion);
        return { kind: 'write', line: remote.line };
      }
      if (remote.kind === 'silent') {
        if (remote.warn) log.warn(remote.warn);
        return { kind: 'silent' };
      }
      log.warn(`Local error for ${safeRemoteText(msg.method, 64)}: ${remote.reason}`);
      return requestId === undefined
        ? { kind: 'silent' }
        : { kind: 'write', line: localError(requestId, remote.reason, remote.httpStatus) };
    };
    const fail = (reason: string): BridgeOutcome =>
      finish({ kind: 'local', reason, httpStatus: null });

    // Header problems are the client's request, not a proxy fault: -32600, and no auth traffic.
    const built = headersFromPlan(msg.headers, msg.method, state.legacyVersion);
    if (!built.ok) {
      log.warn(`Rejected ${safeRemoteText(msg.method, 64)}: ${built.reason}`);
      return requestId === undefined
        ? { kind: 'silent' }
        : { kind: 'write', line: protocolError(-32600, built.reason, requestId) };
    }

    let token: string;
    try {
      token = await raceAbort(strategy.getAccessToken(), signal);
    } catch (err: unknown) {
      if (err instanceof AbortedError) throw err;
      log.error(`Failed to get access token: ${describeError(err)}`);
      return fail('No access token available — authentication required');
    }

    const instanceUrl = strategy.getInstanceUrl() ?? config.instanceUrl;
    const first = await post(msg, built.headers, instanceUrl, token, signal);

    // 401 — attempt single re-auth then retry.
    if (first.status === 401 && isInvalidSession(first.body)) {
      log.warn('Received INVALID_SESSION_ID (HTTP 401) — attempting re-authentication');

      // The strategy coalesces concurrent calls and ignores a 401 for a token
      // it has already replaced, so parallel failures cause one refresh.
      let newAuth;
      try {
        newAuth = await raceAbort(strategy.reauthenticate(token), signal);
      } catch (err: unknown) {
        if (err instanceof AbortedError) throw err;
        log.error(`Re-authentication failed: ${describeError(err)}`);

        // T022: Differentiate error types in client-facing message.
        if (err instanceof ConnectivityError) {
          return fail('Session expired and cannot reach Salesforce for re-authentication — check network connection');
        }
        if (err instanceof InvalidCredentialsError) {
          return fail('Session expired and credentials were rejected — run salesforce-mcp-lib login again');
        }
        if (err instanceof SessionExpiredError) {
          return fail('Session expired and refresh token is no longer valid — run salesforce-mcp-lib login again');
        }
        return fail('Session expired and re-authentication failed — please verify External Client App credentials');
      }
      log.warn('Re-authentication successful — retrying original request');
      const retry = await post(msg, built.headers, newAuth.instance_url, newAuth.access_token, signal);
      if (retry.status >= 200 && retry.status < 300) {
        log.info('Retry after re-authentication succeeded');
      } else {
        log.error(`Retry after re-authentication returned HTTP ${retry.status}`);
      }
      return finish(interpretRemote(retry.status, retry.body, requestId));
    }

    return finish(interpretRemote(first.status, first.body, requestId));
  }

  function rememberLegacyVersion(version: string | undefined): void {
    if (version !== undefined && version.length <= 256 && /^[\x21-\x7E]+$/.test(version)) {
      state.legacyVersion = version;
    }
  }

  async function forward(msg: ForwardableMessage, signal?: AbortSignal): Promise<BridgeOutcome> {
    const requestId = msg.kind === 'request' ? msg.id : undefined;
    const silentOrError = (reason: string, status: number | null): BridgeOutcome => {
      log.warn(`Local error for ${safeRemoteText(msg.method, 64)}: ${reason}`);
      return requestId === undefined
        ? { kind: 'silent' }
        : { kind: 'write', line: localError(requestId, reason, status) };
    };
    if (signal?.aborted) return { kind: 'silent' };

    const ac = new AbortController();
    let timedOut = false;
    const timer = setTimeout(() => {
      timedOut = true;
      ac.abort();
    }, timeoutMs);
    const onAbort = (): void => ac.abort();
    signal?.addEventListener('abort', onAbort, { once: true });
    try {
      return await exchange(msg, ac.signal);
    } catch (err: unknown) {
      if (signal?.aborted) return { kind: 'silent' };
      if (timedOut) return silentOrError(`Request timed out after ${timeoutMs} ms`, null);
      if (err instanceof ResponseTooLargeError) {
        return silentOrError('The remote response exceeds the 8 MiB limit', null);
      }
      if (err instanceof LocalReject) return silentOrError(err.message, null);
      // Network and target errors: log the cause, keep it out of the client error.
      log.error(`Forwarding failed: ${(err as NodeJS.ErrnoException)?.code ?? (err instanceof Error ? err.name : 'unknown error')}`);
      return silentOrError('Could not reach the remote endpoint', null);
    } finally {
      clearTimeout(timer);
      signal?.removeEventListener('abort', onAbort);
    }
  }

  return { forward };
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/** A rejection whose message is already safe for the client. */
class LocalReject extends Error {}

interface HttpResult {
  status: number;
  body: string;
}

function raceAbort<T>(promise: Promise<T>, signal: AbortSignal): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    if (signal.aborted) {
      reject(new AbortedError());
      return;
    }
    const onAbort = (): void => reject(new AbortedError());
    signal.addEventListener('abort', onAbort, { once: true });
    promise.then(
      (value) => {
        signal.removeEventListener('abort', onAbort);
        resolve(value);
      },
      (err: unknown) => {
        signal.removeEventListener('abort', onAbort);
        reject(err);
      }
    );
  });
}

function postJsonRpc(
  url: URL,
  token: string,
  body: string,
  protocolHeaders: Record<string, string>,
  signal: AbortSignal
): Promise<HttpResult> {
  return new Promise<HttpResult>((resolve, reject) => {
    const transport = url.protocol === 'https:' ? https : http;

    const req = transport.request(
      url,
      {
        method: 'POST',
        signal,
        headers: {
          ...protocolHeaders,
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(body).toString(),
          Authorization: `Bearer ${token}`,
          Accept: 'application/json, text/event-stream',
        },
      },
      (res) => {
        const declared = Number(res.headers['content-length']);
        if (declared > MAX_RESPONSE_BYTES) {
          res.destroy();
          reject(new ResponseTooLargeError());
          return;
        }
        const chunks: Buffer[] = [];
        let size = 0;
        res.on('data', (chunk: Buffer) => {
          size += chunk.length;
          if (size > MAX_RESPONSE_BYTES) {
            res.destroy();
            reject(new ResponseTooLargeError());
            return;
          }
          chunks.push(chunk);
        });
        res.on('end', () => {
          resolve({
            status: res.statusCode ?? 0,
            body: Buffer.concat(chunks).toString('utf-8'),
          });
        });
        res.on('error', reject);
        res.on('close', () => reject(new Error('Connection closed before the response completed')));
      }
    );

    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

/** Check whether a 401 body indicates INVALID_SESSION_ID. */
function isInvalidSession(body: string): boolean {
  return body.includes('INVALID_SESSION_ID');
}
