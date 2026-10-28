/**
 * Bounded form POST shared by the OAuth clients (client credentials, code
 * exchange, refresh). One total deadline covers connect, headers and body, the
 * response body is capped, and every failure destroys the socket so no auth
 * handle outlives the call.
 */

import https from 'node:https';
import http from 'node:http';
import { URL } from 'node:url';
import { ConnectivityError, SalesforceAuthError } from './errors.js';
import { assertSecureTransport } from './urlPolicy.js';

/** Total time one token request may take. */
export const AUTH_REQUEST_TIMEOUT_MS = 30_000;
/** Largest token endpoint response accepted. */
export const MAX_AUTH_RESPONSE_BYTES = 1024 * 1024;

export interface PostFormOptions {
  timeoutMs?: number;
  maxBytes?: number;
}

/**
 * POST `application/x-www-form-urlencoded` and resolve with the response body
 * whatever the status (OAuth error bodies are parsed by the caller).
 *
 * @throws SalesforceAuthError before any socket is opened when the URL would
 *   expose credentials (non-https, non-loopback), or when the body is too large.
 * @throws ConnectivityError on network failure or deadline.
 */
export function postForm(url: URL, body: string, options: PostFormOptions = {}): Promise<string> {
  const timeoutMs = options.timeoutMs ?? AUTH_REQUEST_TIMEOUT_MS;
  const maxBytes = options.maxBytes ?? MAX_AUTH_RESPONSE_BYTES;

  try {
    assertSecureTransport(url, 'OAuth endpoint URL');
  } catch (err: unknown) {
    return Promise.reject(new SalesforceAuthError(`Refusing to send credentials: ${(err as Error).message}`));
  }

  return new Promise<string>((resolve, reject) => {
    const transport = url.protocol === 'https:' ? https : http;
    let settled = false;
    let timer: NodeJS.Timeout | undefined;

    const settle = (outcome: () => void): void => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      req.destroy();
      outcome();
    };
    const fail = (err: Error): void => settle(() => reject(err));
    const unreachable = (cause?: Error): ConnectivityError =>
      new ConnectivityError(
        `Cannot reach ${url.origin}. Check your network connection and instance URL.`,
        cause
      );

    const req = transport.request(
      url,
      {
        method: 'POST',
        // A dedicated agent keeps no pooled socket alive after the call.
        agent: false,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Content-Length': Buffer.byteLength(body).toString(),
          Accept: 'application/json',
          Connection: 'close',
        },
      },
      (res) => {
        const declared = Number(res.headers['content-length']);
        if (declared > maxBytes) {
          fail(new SalesforceAuthError('The OAuth endpoint response is too large'));
          return;
        }
        const chunks: Buffer[] = [];
        let size = 0;
        res.on('data', (chunk: Buffer) => {
          size += chunk.length;
          if (size > maxBytes) {
            fail(new SalesforceAuthError('The OAuth endpoint response is too large'));
            return;
          }
          chunks.push(chunk);
        });
        res.on('end', () => settle(() => resolve(Buffer.concat(chunks).toString('utf-8'))));
        res.on('error', (err: Error) => fail(unreachable(err)));
        res.on('close', () => fail(unreachable()));
      }
    );

    timer = setTimeout(
      () =>
        fail(
          new ConnectivityError(
            `Timed out after ${timeoutMs} ms waiting for ${url.origin}. Check your network connection and instance URL.`
          )
        ),
      timeoutMs
    );
    req.on('error', (err: Error) => fail(unreachable(err)));
    req.write(body);
    req.end();
  });
}
