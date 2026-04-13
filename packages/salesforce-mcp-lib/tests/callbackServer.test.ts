import { afterEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import net from 'node:net';

import { startCallbackServer } from '../src/callbackServer.js';
import { ConsentDeniedError } from '../src/errors.js';

const activeServers: Array<{ close(): void }> = [];

afterEach(() => {
  while (activeServers.length > 0) {
    activeServers.pop()?.close();
  }
});

function registerServer<T extends { close(): void }>(server: T): T {
  activeServers.push(server);
  return server;
}

function httpGet(url: string): Promise<{ statusCode: number; body: string }> {
  return new Promise((resolve, reject) => {
    const req = http.get(url, (res) => {
      const chunks: Buffer[] = [];
      res.on('data', (chunk: Buffer) => chunks.push(chunk));
      res.on('end', () => {
        resolve({
          statusCode: res.statusCode ?? 0,
          body: Buffer.concat(chunks).toString('utf8'),
        });
      });
    });
    req.on('error', reject);
  });
}

function canConnect(host: string, port: number): Promise<boolean> {
  return new Promise((resolve) => {
    const socket = net.connect({ host, port });
    socket.once('connect', () => {
      socket.destroy();
      resolve(true);
    });
    socket.once('error', () => {
      socket.destroy();
      resolve(false);
    });
  });
}

describe('startCallbackServer', () => {
  it('returns a localhost callback URL and resolves a successful callback', async () => {
    const server = registerServer(
      await startCallbackServer({
        port: 0,
        expectedState: 'state-123',
        timeout: 5000,
      }),
    );

    assert.match(server.callbackUrl, /^http:\/\/127\.0\.0\.1:\d+\/oauth\/callback$/);

    const waitPromise = server.waitForCode();
    const response = await httpGet(
      `${server.callbackUrl}?code=auth-code-123&state=state-123`,
    );
    const result = await waitPromise;

    assert.equal(response.statusCode, 200);
    assert.match(response.body, /Login successful/i);
    assert.deepEqual(result, { code: 'auth-code-123', state: 'state-123' });
  });

  it('ignores state mismatch (HTTP 400) and resolves on subsequent valid callback', async () => {
    const server = registerServer(
      await startCallbackServer({
        port: 0,
        expectedState: 'expected-state',
        timeout: 5000,
      }),
    );

    const waitPromise = server.waitForCode();

    // Wrong state → HTTP 400, but server keeps waiting.
    const badResponse = await httpGet(
      `${server.callbackUrl}?code=auth-code-123&state=wrong-state`,
    );
    assert.equal(badResponse.statusCode, 400);
    assert.match(badResponse.body, /Invalid state parameter/);

    // Correct state → promise resolves.
    const goodResponse = await httpGet(
      `${server.callbackUrl}?code=real-code&state=expected-state`,
    );
    assert.equal(goodResponse.statusCode, 200);
    assert.match(goodResponse.body, /Login successful/i);

    const result = await waitPromise;
    assert.deepEqual(result, { code: 'real-code', state: 'expected-state' });
  });

  it('preserves literal percent characters in callback error descriptions', async () => {
    const server = registerServer(
      await startCallbackServer({
        port: 0,
        expectedState: 'state-789',
        timeout: 5000,
      }),
    );

    const waitPromise = server.waitForCode();
    const rejected = assert.rejects(
      waitPromise,
      /OAuth callback error: server_error — contains%/,
    );
    const response = await httpGet(
      `${server.callbackUrl}?error=server_error&error_description=contains%25&state=state-789`,
    );

    assert.equal(response.statusCode, 200);
    assert.match(response.body, /Login Failed/i);
    await rejected;
  });

  it('rejects access_denied as ConsentDeniedError without double-decoding', async () => {
    const server = registerServer(
      await startCallbackServer({
        port: 0,
        expectedState: 'state-999',
        timeout: 5000,
      }),
    );

    const waitPromise = server.waitForCode();
    const rejected = assert.rejects(waitPromise, (err: unknown) => {
      assert.ok(err instanceof ConsentDeniedError);
      assert.match(
        err.message,
        /Authorization was denied.*consent% required/,
      );
      return true;
    });
    const response = await httpGet(
      `${server.callbackUrl}?error=access_denied&error_description=consent%25%20required&state=state-999`,
    );

    assert.equal(response.statusCode, 200);
    assert.match(response.body, /Authorization denied/i);
    await rejected;
  });

  it('ignores error callback with wrong state and keeps waiting for valid callback', async () => {
    const server = registerServer(
      await startCallbackServer({
        port: 0,
        expectedState: 'expected-state',
        timeout: 5000,
      }),
    );

    const waitPromise = server.waitForCode();

    // Spoofed error with wrong state → HTTP 400, server keeps waiting.
    const spoofedError = await httpGet(
      `${server.callbackUrl}?error=access_denied&error_description=spoofed&state=wrong-state`,
    );
    assert.equal(spoofedError.statusCode, 400);
    assert.match(spoofedError.body, /Invalid state parameter/);

    // Spoofed error with no state → HTTP 400, server keeps waiting.
    const noStateError = await httpGet(
      `${server.callbackUrl}?error=access_denied&error_description=spoofed`,
    );
    assert.equal(noStateError.statusCode, 400);
    assert.match(noStateError.body, /Invalid state parameter/);

    // Legitimate success callback → resolves the promise.
    const goodResponse = await httpGet(
      `${server.callbackUrl}?code=real-code&state=expected-state`,
    );
    assert.equal(goodResponse.statusCode, 200);

    const result = await waitPromise;
    assert.deepEqual(result, { code: 'real-code', state: 'expected-state' });
  });

  it('accepts loopback connections on either IPv6 or IPv4 fallback', async () => {
    const server = registerServer(
      await startCallbackServer({
        port: 0,
        expectedState: 'state-456',
        timeout: 5000,
      }),
    );

    const ipv6Reachable = await canConnect('::1', server.port);
    const ipv4Reachable = await canConnect('127.0.0.1', server.port);

    assert.equal(ipv6Reachable || ipv4Reachable, true);
  });
});
