/**
 * MCP bridge — forwards JSON-RPC messages to a Salesforce Apex endpoint.
 * T037 — HTTP transport, 401 re-auth, and error translation.
 * T059 — hardened 401 re-auth: warn logging, sanitized client errors.
 */

import https from 'node:https';
import http from 'node:http';
import { URL } from 'node:url';
import type { BridgeConfig, JsonRpcMessage } from './types.js';
import { RemoteMcpError } from './errors.js';
import { authenticate, getToken, getInstanceUrl } from './oauth.js';

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

/** Represents the forward function returned by createBridge. */
export interface Bridge {
  forward(message: string): Promise<string>;
}

/**
 * Create a bridge that forwards raw JSON-RPC strings to Salesforce.
 *
 * The bridge reads the current OAuth token from the oauth module and
 * handles transparent 401 re-authentication (single retry).
 *
 * @param config Bridge configuration (instance URL, credentials, endpoint).
 * @param logger Optional logger for operational messages (warn-level re-auth events).
 */
export function createBridge(config: BridgeConfig, logger?: BridgeLogger): Bridge {
  const log = logger ?? nullLogger;

  async function forward(message: string): Promise<string> {
    // Extract the id from the incoming message so error responses can echo it.
    let requestId: string | number | null = null;
    try {
      const parsed = JSON.parse(message) as JsonRpcMessage;
      requestId = parsed.id ?? null;
    } catch {
      // If the inbound message is not valid JSON we still forward it and let
      // the remote endpoint deal with the parse error.
    }

    const token = getToken();
    if (token === null) {
      log.error('Bridge forward called with no cached access token');
      return jsonRpcError(
        requestId,
        -32603,
        'No access token available — authentication required'
      );
    }

    const instanceUrl = getInstanceUrl() ?? config.instanceUrl;

    // First attempt.
    const first = await postJsonRpc(instanceUrl, config.endpoint, token, message);

    if (first.status === 200) {
      return first.body;
    }

    // 401 — attempt single re-auth then retry.
    if (first.status === 401 && isInvalidSession(first.body)) {
      log.warn('Received INVALID_SESSION_ID (HTTP 401) — attempting re-authentication');
      try {
        const newAuth = await authenticate(config);
        log.warn('Re-authentication successful — retrying original request');
        const retry = await postJsonRpc(
          newAuth.instance_url,
          config.endpoint,
          newAuth.access_token,
          message
        );
        if (retry.status === 200) {
          log.info('Retry after re-authentication succeeded');
          return retry.body;
        }
        log.error(`Retry after re-authentication returned HTTP ${retry.status}`);
        return sanitizedHttpError(requestId, retry.status);
      } catch (err: unknown) {
        const detail = err instanceof Error ? err.message : String(err);
        log.error(`Re-authentication failed: ${detail}`);
        return jsonRpcError(
          requestId,
          -32603,
          'Session expired and re-authentication failed — please verify External Client App credentials'
        );
      }
    }

    return sanitizedHttpError(requestId, first.status);
  }

  return { forward };
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

interface HttpResult {
  status: number;
  body: string;
}

function postJsonRpc(
  instanceUrl: string,
  endpoint: string,
  token: string,
  body: string
): Promise<HttpResult> {
  return new Promise<HttpResult>((resolve, reject) => {
    const url = new URL(endpoint, instanceUrl);
    const transport = url.protocol === 'https:' ? https : http;

    const req = transport.request(
      url,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(body).toString(),
          Authorization: `Bearer ${token}`,
          Accept: 'application/json',
        },
      },
      (res) => {
        const chunks: Buffer[] = [];
        res.on('data', (chunk: Buffer) => chunks.push(chunk));
        res.on('end', () => {
          resolve({
            status: res.statusCode ?? 0,
            body: Buffer.concat(chunks).toString('utf-8'),
          });
        });
      }
    );

    req.on('error', (err: Error) => {
      reject(
        new RemoteMcpError(
          `Network error forwarding JSON-RPC: ${err.message}`,
          0,
          ''
        )
      );
    });

    req.write(body);
    req.end();
  });
}

/** Check whether a 401 body indicates INVALID_SESSION_ID. */
function isInvalidSession(body: string): boolean {
  return body.includes('INVALID_SESSION_ID');
}

/**
 * Return a sanitized JSON-RPC error for the client.
 *
 * This intentionally does NOT expose the raw Salesforce error body to the
 * client.  Detailed error information is only written to the server-side
 * log (which goes to stderr and is never visible to the MCP client).
 */
function sanitizedHttpError(
  requestId: string | number | null,
  status: number
): string {
  let detail: string;

  if (status === 500) {
    detail = 'The remote Apex endpoint returned an internal error';
  } else if (status === 401 || status === 403) {
    detail = 'Authorization error communicating with the remote endpoint';
  } else {
    detail = `The remote endpoint returned an unexpected status (HTTP ${status})`;
  }

  return jsonRpcError(requestId, -32603, detail);
}

/** Build a serialised JSON-RPC 2.0 error response. */
function jsonRpcError(
  id: string | number | null,
  code: number,
  message: string
): string {
  const response: JsonRpcMessage = {
    jsonrpc: '2.0',
    id: id,
    error: { code, message },
  };
  return JSON.stringify(response);
}
