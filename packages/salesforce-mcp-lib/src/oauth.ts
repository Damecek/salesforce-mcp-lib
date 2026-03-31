/**
 * Salesforce OAuth 2.0 client-credentials flow.
 * T036 — authenticate, cache token, expose getter.
 */

import https from 'node:https';
import http from 'node:http';
import { URL } from 'node:url';
import type { BridgeConfig, OAuthTokenResponse } from './types.js';
import { SalesforceAuthError } from './errors.js';

/** Cached token state (module-level singleton). */
let cachedToken: string | null = null;
let cachedInstanceUrl: string | null = null;

/**
 * Authenticate against Salesforce using the client_credentials grant type.
 *
 * On success the access_token and instance_url are cached internally so
 * that subsequent calls to {@link getToken} return the latest value.
 *
 * @throws {SalesforceAuthError} on any network or authentication failure.
 */
export async function authenticate(
  config: BridgeConfig
): Promise<OAuthTokenResponse> {
  const tokenUrl = new URL('/services/oauth2/token', config.instanceUrl);

  const body = new URLSearchParams({
    grant_type: 'client_credentials',
    client_id: config.clientId,
    client_secret: config.clientSecret,
  }).toString();

  const responseBody = await postForm(tokenUrl, body);

  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(responseBody) as Record<string, unknown>;
  } catch {
    throw new SalesforceAuthError(
      `OAuth response is not valid JSON: ${responseBody.slice(0, 200)}`
    );
  }

  if (typeof parsed['error'] === 'string') {
    const desc =
      typeof parsed['error_description'] === 'string'
        ? parsed['error_description']
        : 'unknown';
    throw new SalesforceAuthError(
      `OAuth error: ${parsed['error']} - ${desc}`
    );
  }

  if (typeof parsed['access_token'] !== 'string') {
    throw new SalesforceAuthError(
      'OAuth response missing access_token'
    );
  }

  const tokenResponse: OAuthTokenResponse = {
    access_token: parsed['access_token'] as string,
    instance_url: (parsed['instance_url'] as string) ?? config.instanceUrl,
    token_type: (parsed['token_type'] as string) ?? 'Bearer',
    id: (parsed['id'] as string) ?? '',
    issued_at: (parsed['issued_at'] as string) ?? String(Date.now()),
  };

  // Cache for later retrieval.
  cachedToken = tokenResponse.access_token;
  cachedInstanceUrl = tokenResponse.instance_url;

  return tokenResponse;
}

/** Return the most recently cached access token, or null. */
export function getToken(): string | null {
  return cachedToken;
}

/** Return the most recently cached instance URL, or null. */
export function getInstanceUrl(): string | null {
  return cachedInstanceUrl;
}

/** Reset cached state (useful for testing). */
export function resetTokenCache(): void {
  cachedToken = null;
  cachedInstanceUrl = null;
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/**
 * Low-level HTTPS/HTTP POST with application/x-www-form-urlencoded body.
 * Uses node:https or node:http based on the URL protocol.
 */
function postForm(url: URL, body: string): Promise<string> {
  return new Promise<string>((resolve, reject) => {
    const transport = url.protocol === 'https:' ? https : http;

    const req = transport.request(
      url,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Content-Length': Buffer.byteLength(body).toString(),
          Accept: 'application/json',
        },
      },
      (res) => {
        const chunks: Buffer[] = [];
        res.on('data', (chunk: Buffer) => chunks.push(chunk));
        res.on('end', () => {
          const text = Buffer.concat(chunks).toString('utf-8');
          if (
            res.statusCode !== undefined &&
            (res.statusCode < 200 || res.statusCode >= 300)
          ) {
            reject(
              new SalesforceAuthError(
                `OAuth token request failed with HTTP ${res.statusCode}: ${text.slice(0, 300)}`
              )
            );
            return;
          }
          resolve(text);
        });
      }
    );

    req.on('error', (err: Error) => {
      reject(
        new SalesforceAuthError(`OAuth request network error: ${err.message}`)
      );
    });

    req.write(body);
    req.end();
  });
}
