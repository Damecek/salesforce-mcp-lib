/**
 * Transport policy shared by config parsing, the OAuth clients and the bridge.
 * Credentials (client_secret, refresh and access tokens) travel only over https,
 * or over plain http to an exact loopback host (local test servers).
 */

import { URL } from 'node:url';

/** `localhost`, `[::1]` or an IPv4 address in 127.0.0.0/8, as normalised by `URL.hostname`. */
export function isLoopbackHost(hostname: string): boolean {
  return hostname === 'localhost' || hostname === '[::1]' || /^127\.\d+\.\d+\.\d+$/.test(hostname);
}

export function isSecureTransport(url: URL): boolean {
  return url.protocol === 'https:' || (url.protocol === 'http:' && isLoopbackHost(url.hostname));
}

/**
 * @throws Error whose message never contains the URL.
 */
export function assertSecureTransport(url: URL, what: string): void {
  if (url.username || url.password) {
    throw new Error(`${what} must not contain credentials`);
  }
  if (!isSecureTransport(url)) {
    throw new Error(`${what} must use https (plain http is allowed only for localhost, 127.x.x.x and [::1])`);
  }
}
