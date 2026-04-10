/**
 * Local HTTP server for OAuth redirect callback.
 * T005 — accepts GET /oauth/callback, extracts code + state, responds with success page.
 * T026 — handles error query params, validates state for CSRF prevention.
 */

import http from 'node:http';
import { URL } from 'node:url';
import type { CallbackResult } from './types.js';
import { ConsentDeniedError } from './errors.js';

/** Options for the callback server. */
export interface CallbackServerOptions {
  /** Port to listen on. Defaults to 13338. */
  port?: number;
  /** Timeout in milliseconds. Defaults to 120000 (2 minutes). */
  timeout?: number;
  /** Expected state value for CSRF verification. */
  expectedState?: string;
  /** Callback host shown in the redirect URL. Defaults to localhost. */
  callbackHost?: string;
}

/** Handle to the running callback server. */
export interface CallbackServer {
  /** The port the server is actually listening on. */
  readonly port: number;
  /** The full callback URL (http://localhost:{port}/oauth/callback). */
  readonly callbackUrl: string;
  /** Wait for the authorization code. Resolves with code + state. */
  waitForCode(): Promise<CallbackResult>;
  /** Shut down the server. */
  close(): void;
}

/** Security headers applied to all HTML responses. */
const SECURITY_HEADERS = {
  'Content-Type': 'text/html',
  'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'",
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY',
};

/** HTML page shown to user after successful authorization. */
const SUCCESS_HTML = `<!DOCTYPE html>
<html><head><title>Login Successful</title></head>
<body style="font-family:system-ui,sans-serif;display:flex;justify-content:center;align-items:center;height:100vh;margin:0;background:#f0f9ff">
<div style="text-align:center;padding:2rem">
<h1 style="color:#16a34a">&#10003; Login successful!</h1>
<p>You can close this tab and return to your terminal.</p>
<p style="color:#6b7280;font-size:0.875rem">You can now start the MCP server with:<br><code>salesforce-mcp-lib --instance-url &lt;url&gt; --client-id &lt;id&gt; --endpoint &lt;path&gt;</code></p>
</div></body></html>`;

/** HTML page shown when authorization was denied. */
const ERROR_HTML = `<!DOCTYPE html>
<html><head><title>Login Failed</title></head>
<body style="font-family:system-ui,sans-serif;display:flex;justify-content:center;align-items:center;height:100vh;margin:0;background:#fef2f2">
<div style="text-align:center;padding:2rem">
<h1 style="color:#dc2626">&#10007; Authorization denied</h1>
<p>The authorization request was denied or failed.</p>
<p style="color:#6b7280;font-size:0.875rem">Check your terminal for details and try again with:<br><code>salesforce-mcp-lib login --instance-url &lt;url&gt; --client-id &lt;id&gt;</code></p>
</div></body></html>`;

/**
 * Start a local HTTP server that waits for the OAuth callback.
 * Attempts the configured port first, then increments up to 5 times if occupied.
 */
export function startCallbackServer(
  options?: CallbackServerOptions
): Promise<CallbackServer> {
  const basePort = options?.port ?? 13338;
  const timeout = options?.timeout ?? 120_000;
  const expectedState = options?.expectedState;
  const callbackHost = options?.callbackHost ?? 'localhost';
  const maxAttempts = 5;

  return new Promise<CallbackServer>((resolveStart, rejectStart) => {
    let resolveCode: ((result: CallbackResult) => void) | null = null;
    let rejectCode: ((err: Error) => void) | null = null;
    let timeoutHandle: ReturnType<typeof setTimeout> | null = null;
    let settled = false;

    const codePromise = new Promise<CallbackResult>((res, rej) => {
      resolveCode = res;
      rejectCode = rej;
    });

    const server = http.createServer((req, res) => {
      // Only accept GET /oauth/callback
      const reqUrl = new URL(req.url ?? '/', `http://localhost`);
      if (req.method !== 'GET' || reqUrl.pathname !== '/oauth/callback') {
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('Not Found');
        return;
      }

      // Check for error params (Salesforce sends error + error_description on deny).
      const errorParam = reqUrl.searchParams.get('error');
      if (errorParam) {
        const errorDesc =
          reqUrl.searchParams.get('error_description') ?? 'Unknown error';
        res.writeHead(200, SECURITY_HEADERS);
        res.end(ERROR_HTML);
        if (!settled) {
          settled = true;
          if (timeoutHandle) clearTimeout(timeoutHandle);
          if (errorParam === 'access_denied') {
            rejectCode!(
              new ConsentDeniedError(
                `Authorization was denied. The application requires your consent to access Salesforce. (${decodeURIComponent(errorDesc)})`
              )
            );
          } else {
            rejectCode!(
              new Error(
                `OAuth callback error: ${errorParam} — ${decodeURIComponent(errorDesc)}`
              )
            );
          }
        }
        return;
      }

      const code = reqUrl.searchParams.get('code');
      const state = reqUrl.searchParams.get('state');

      if (!code) {
        res.writeHead(400, { 'Content-Type': 'text/plain' });
        res.end('Missing authorization code');
        return;
      }

      // Validate state for CSRF prevention.
      if (expectedState && state !== expectedState) {
        res.writeHead(400, { 'Content-Type': 'text/plain' });
        res.end('Invalid state parameter — possible CSRF attack');
        if (!settled) {
          settled = true;
          if (timeoutHandle) clearTimeout(timeoutHandle);
          rejectCode!(
            new Error(
              'OAuth state mismatch — the callback state does not match the expected value. This may indicate a CSRF attack.'
            )
          );
        }
        return;
      }

      res.writeHead(200, SECURITY_HEADERS);
      res.end(SUCCESS_HTML);

      if (!settled) {
        settled = true;
        if (timeoutHandle) clearTimeout(timeoutHandle);
        resolveCode!({ code, state: state ?? '' });
      }
    });

    function tryListen(
      port: number,
      attempt: number,
      listenOptions: { host: string; ipv6Only?: boolean }
    ): void {
      const onError = (err: NodeJS.ErrnoException): void => {
        server.removeListener('listening', onListening);
        if (err.code === 'EADDRINUSE' && attempt < maxAttempts) {
          tryListen(port + 1, attempt + 1, listenOptions);
        } else if (
          listenOptions.host === '::' &&
          (err.code === 'EAFNOSUPPORT' || err.code === 'EADDRNOTAVAIL')
        ) {
          tryListen(port, attempt, { host: '127.0.0.1' });
        } else {
          rejectStart(
            new Error(
              `Cannot start callback server: ${err.message}. Tried ports ${basePort}–${port}.`
            )
          );
        }
      };

      const onListening = (): void => {
        server.removeListener('error', onError);
        const actualPort = (server.address() as { port: number }).port;
        const callbackUrl = `http://${callbackHost}:${actualPort}/oauth/callback`;

        // Set timeout for code reception.
        timeoutHandle = setTimeout(() => {
          if (!settled) {
            settled = true;
            server.close();
            rejectCode!(
              new Error(
                `Login timed out after ${timeout / 1000} seconds. No authorization code received. ` +
                  'Please try again with: salesforce-mcp-lib login --instance-url ... --client-id ...'
              )
            );
          }
        }, timeout);

        const callbackServer: CallbackServer = {
          port: actualPort,
          callbackUrl,
          waitForCode(): Promise<CallbackResult> {
            return codePromise;
          },
          close(): void {
            if (timeoutHandle) clearTimeout(timeoutHandle);
            server.close();
          },
        };

        resolveStart(callbackServer);
      };

      server.once('error', onError);
      server.once('listening', onListening);
      server.listen({ port, ...listenOptions });
    }

    tryListen(basePort, 1, { host: '::', ipv6Only: false });
  });
}
