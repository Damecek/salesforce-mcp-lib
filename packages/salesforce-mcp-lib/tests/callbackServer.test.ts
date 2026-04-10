import { afterEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import net from 'node:net';

import { startCallbackServer } from '../src/callbackServer.js';

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

    assert.match(server.callbackUrl, /^http:\/\/localhost:\d+\/oauth\/callback$/);

    const waitPromise = server.waitForCode();
    const response = await httpGet(
      `${server.callbackUrl}?code=auth-code-123&state=state-123`,
    );
    const result = await waitPromise;

    assert.equal(response.statusCode, 200);
    assert.match(response.body, /Login successful/i);
    assert.deepEqual(result, { code: 'auth-code-123', state: 'state-123' });
  });

  it('rejects state mismatch and returns HTTP 400', async () => {
    const server = registerServer(
      await startCallbackServer({
        port: 0,
        expectedState: 'expected-state',
        timeout: 5000,
      }),
    );

    const waitPromise = server.waitForCode();
    const rejected = assert.rejects(waitPromise, /OAuth state mismatch/);
    const response = await httpGet(
      `${server.callbackUrl}?code=auth-code-123&state=wrong-state`,
    );

    assert.equal(response.statusCode, 400);
    assert.match(response.body, /Invalid state parameter/);
    await rejected;
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
