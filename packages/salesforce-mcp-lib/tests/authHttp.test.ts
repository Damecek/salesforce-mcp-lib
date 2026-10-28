import { afterEach, beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import fs from 'node:fs';
import http from 'node:http';
import https from 'node:https';
import type { IncomingMessage, ServerResponse } from 'node:http';
import type { Socket } from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

import { postForm } from '../src/authHttp.js';
import { authenticate, resetTokenCache } from '../src/oauth.js';
import { exchangeCodeForTokens, refreshAccessToken } from '../src/perUserAuth.js';
import { PerUserAuthStrategy } from '../src/authStrategy.js';
import { saveTokens } from '../src/tokenStore.js';
import { ConnectivityError, SalesforceAuthError } from '../src/errors.js';

const quietLogger = { debug() {}, info() {}, warn() {}, error() {} };
const sleep = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));

async function until(condition: () => boolean, ms = 3000): Promise<void> {
  const deadline = Date.now() + ms;
  while (!condition()) {
    if (Date.now() > deadline) assert.fail('condition not met in time');
    await sleep(10);
  }
}

/** A loopback server that tracks every socket so tests can assert they were closed. */
class TrackedServer {
  readonly server: http.Server;
  readonly sockets = new Set<Socket>();
  connections = 0;
  closedSockets = 0;
  url = '';
  private intervals: NodeJS.Timeout[] = [];

  constructor(handler: (req: IncomingMessage, res: ServerResponse, server: TrackedServer) => void) {
    this.server = http.createServer((req, res) => handler(req, res, this));
    this.server.on('connection', (socket) => {
      this.connections++;
      this.sockets.add(socket);
      socket.on('close', () => {
        this.closedSockets++;
        this.sockets.delete(socket);
      });
    });
  }

  async start(): Promise<void> {
    await new Promise<void>((resolve) => this.server.listen(0, '127.0.0.1', resolve));
    this.url = `http://127.0.0.1:${(this.server.address() as { port: number }).port}`;
  }

  every(ms: number, fn: () => void): void {
    this.intervals.push(setInterval(fn, ms));
  }

  async stop(): Promise<void> {
    this.intervals.forEach(clearInterval);
    for (const socket of this.sockets) socket.destroy();
    await new Promise<void>((resolve) => this.server.close(() => resolve()));
  }
}

let current: TrackedServer | undefined;
afterEach(async () => {
  await current?.stop();
  current = undefined;
  resetTokenCache();
});

async function serve(handler: (req: IncomingMessage, res: ServerResponse, s: TrackedServer) => void): Promise<TrackedServer> {
  current = new TrackedServer(handler);
  await current.start();
  return current;
}

const tokenUrl = (s: TrackedServer): URL => new URL('/services/oauth2/token', s.url);

describe('postForm deadline and bounds (M1)', () => {
  it('a stalled endpoint is abandoned at the deadline and its socket is closed', async () => {
    const s = await serve((req) => {
      req.resume(); // accept the request, never answer
    });
    const started = Date.now();

    await assert.rejects(
      () => postForm(tokenUrl(s), 'a=b', { timeoutMs: 150 }),
      (err: unknown) => err instanceof ConnectivityError && /Timed out/.test(err.message)
    );

    assert.ok(Date.now() - started < 1500);
    await until(() => s.closedSockets === 1);
    assert.equal(s.connections, 1, 'no retry after the timeout');
    await sleep(300);
    assert.equal(s.connections, 1, 'no uncontrolled new auth attempts');
  });

  it('a slow trickle cannot extend the total deadline', async () => {
    const s = await serve((req, res, self) => {
      req.resume();
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.write(' ');
      self.every(20, () => res.write(' '));
    });
    const started = Date.now();

    await assert.rejects(
      () => postForm(tokenUrl(s), 'a=b', { timeoutMs: 250 }),
      (err: unknown) => err instanceof ConnectivityError
    );

    const elapsed = Date.now() - started;
    assert.ok(elapsed >= 200 && elapsed < 1500, `elapsed ${elapsed}`);
    await until(() => s.closedSockets === 1);
    assert.equal(s.connections, 1);
  });

  it('rejects a declared oversize body and closes the socket', async () => {
    const s = await serve((req, res) => {
      req.resume();
      res.writeHead(200, { 'Content-Length': String(5 * 1024 * 1024) });
      res.write('x');
    });

    await assert.rejects(
      () => postForm(tokenUrl(s), 'a=b', { maxBytes: 1024 }),
      (err: unknown) => err instanceof SalesforceAuthError && /too large/.test(err.message)
    );
    await until(() => s.closedSockets === 1);
  });

  it('rejects a chunked body that grows past the cap and closes the socket', async () => {
    const s = await serve((req, res, self) => {
      req.resume();
      res.writeHead(200);
      self.every(5, () => res.write(Buffer.alloc(512, 0x61)));
    });

    await assert.rejects(
      () => postForm(tokenUrl(s), 'a=b', { maxBytes: 1500 }),
      (err: unknown) => err instanceof SalesforceAuthError && /too large/.test(err.message)
    );
    await until(() => s.closedSockets === 1);
  });

  it('a server that drops the connection mid-body is a connectivity error', async () => {
    const s = await serve((req, res) => {
      req.resume();
      res.writeHead(200, { 'Content-Length': '100' });
      res.write('partial');
      setTimeout(() => res.socket?.destroy(), 20);
    });

    await assert.rejects(() => postForm(tokenUrl(s), 'a=b'), ConnectivityError);
  });

  it('returns the body whatever the status, so OAuth error bodies reach the caller', async () => {
    const s = await serve((req, res) => {
      req.resume();
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end('{"error":"invalid_client"}');
    });

    assert.equal(await postForm(tokenUrl(s), 'a=b'), '{"error":"invalid_client"}');
  });

  it('lets a CLI process exit on its own after a stalled endpoint times out', async () => {
    const s = await serve((req) => {
      req.resume();
    });
    const here = path.dirname(fileURLToPath(import.meta.url));
    const moduleUrl = pathToFileURL(path.join(here, '..', 'src', 'authHttp.ts')).href;
    const script = `
      const { postForm } = await import(process.argv[1]);
      try { await postForm(new URL(process.argv[2]), 'a=b', { timeoutMs: 200 }); }
      catch (e) { console.log('rejected ' + e.name); }
    `;

    const output = await new Promise<string>((resolve, reject) => {
      execFile(
        process.execPath,
        ['--import', 'tsx', '--input-type=module', '-e', script, moduleUrl, tokenUrl(s).href],
        { cwd: path.join(here, '..'), timeout: 15000 },
        (err, stdout) => (err ? reject(err) : resolve(stdout))
      );
    });

    assert.match(output, /rejected ConnectivityError/);
    await until(() => s.closedSockets === 1);
  });
});

describe('OAuth entry points use the deadline (M1)', () => {
  it('authenticate() gives up on a stalled endpoint and does not retry', async () => {
    const s = await serve((req) => {
      req.resume();
    });

    await assert.rejects(
      () =>
        authenticate({
          instanceUrl: s.url,
          clientId: 'cid',
          clientSecret: 'csec',
          endpoint: '/e',
          authTimeoutMs: 150,
        }),
      ConnectivityError
    );
    await until(() => s.closedSockets === 1);
    await sleep(200);
    assert.equal(s.connections, 1);
  });

  it('refreshAccessToken() and exchangeCodeForTokens() accept the same bounds', async () => {
    const s = await serve((req) => {
      req.resume();
    });

    await assert.rejects(() => refreshAccessToken(s.url, 'cid', 'rt', undefined, { timeoutMs: 120 }), ConnectivityError);
    await assert.rejects(
      () => exchangeCodeForTokens(s.url, 'cid', 'code', 'http://localhost:1/cb', 'v', undefined, { timeoutMs: 120 }),
      ConnectivityError
    );
    await until(() => s.closedSockets === 2);
  });
});

describe('credentials only over https or exact loopback (M6)', () => {
  let httpCalls: number;
  let httpsCalls: number;
  const restore: Array<() => void> = [];

  beforeEach(() => {
    httpCalls = 0;
    httpsCalls = 0;
    const realHttp = http.request;
    const realHttps = https.request;
    (http as { request: unknown }).request = (...args: unknown[]) => (httpCalls++, (realHttp as (...a: unknown[]) => unknown)(...args));
    (https as { request: unknown }).request = (...args: unknown[]) => (httpsCalls++, (realHttps as (...a: unknown[]) => unknown)(...args));
    restore.push(() => {
      (http as { request: unknown }).request = realHttp;
      (https as { request: unknown }).request = realHttps;
    });
  });
  afterEach(() => restore.splice(0).forEach((fn) => fn()));

  const BAD = ['http://login.example.com', 'http://localhost.evil.com', 'http://127.0.0.1.evil.com', 'http://192.0.2.1:8443', 'ftp://example.com'];

  for (const instanceUrl of BAD) {
    it(`authenticate() refuses ${instanceUrl} before any request, without echoing the secret`, async () => {
      await assert.rejects(
        () => authenticate({ instanceUrl, clientId: 'cid', clientSecret: 'S3CRET-VALUE', endpoint: '/e' }),
        (err: unknown) => {
          assert.ok(err instanceof SalesforceAuthError);
          assert.match(err.message, /https/);
          assert.ok(!err.message.includes('S3CRET-VALUE'));
          return true;
        }
      );
      assert.equal(httpCalls + httpsCalls, 0);
    });

    it(`refreshAccessToken() refuses ${instanceUrl} before any request`, async () => {
      await assert.rejects(() => refreshAccessToken(instanceUrl, 'cid', 'REFRESH-VALUE', 'S3CRET-VALUE'), SalesforceAuthError);
      assert.equal(httpCalls + httpsCalls, 0);
    });
  }

  it('exchangeCodeForTokens() refuses plain http to a remote host', async () => {
    await assert.rejects(
      () => exchangeCodeForTokens('http://login.example.com', 'cid', 'code', 'http://localhost:1/cb', 'verifier', 'S3CRET-VALUE'),
      SalesforceAuthError
    );
    assert.equal(httpCalls + httpsCalls, 0);
  });

  it('a stored refresh token is not sent to a non-https instance', async () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sfmcp-policy-'));
    const saved = process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'];
    process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'] = dir;
    try {
      const instanceUrl = 'http://login.example.com';
      saveTokens(instanceUrl, 'cid', {
        accessToken: 'A1', refreshToken: 'REFRESH-VALUE', instanceUrl, tokenType: 'Bearer', issuedAt: 1, identityUrl: 'id',
      });
      const strategy = new PerUserAuthStrategy(
        { instanceUrl, clientId: 'cid', endpoint: '/e' },
        quietLogger,
        { allowInteractiveLogin: false }
      );

      await assert.rejects(() => strategy.reauthenticate('A1'), SalesforceAuthError);
      assert.equal(httpCalls + httpsCalls, 0);
    } finally {
      if (saved === undefined) delete process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'];
      else process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'] = saved;
      fs.rmSync(dir, { recursive: true, force: true });
    }
  });

  it('loopback http still reaches a local mock', async () => {
    const s = await serve((req, res) => {
      req.resume();
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end('{"access_token":"tok"}');
    });

    for (const host of ['127.0.0.1', 'localhost']) {
      const url = new URL(s.url);
      url.hostname = host;
      const result = await authenticate({ instanceUrl: url.origin, clientId: 'cid', clientSecret: 'csec', endpoint: '/e' });
      assert.equal(result.access_token, 'tok');
    }
  });
});

describe('auth errors do not carry remote bodies (redaction)', () => {
  it('an invalid JSON body is not echoed into the error', async () => {
    const s = await serve((req, res) => {
      req.resume();
      res.writeHead(200);
      res.end('<html>access_token=LEAKED-TOKEN refresh_token=LEAKED-REFRESH</html>');
    });

    for (const call of [
      () => authenticate({ instanceUrl: s.url, clientId: 'cid', clientSecret: 'csec', endpoint: '/e' }),
      () => refreshAccessToken(s.url, 'cid', 'rt'),
    ]) {
      await assert.rejects(call, (err: unknown) => {
        assert.ok(err instanceof SalesforceAuthError);
        assert.ok(!/LEAKED/.test(err.message), err.message);
        return true;
      });
    }
  });

  it('error_description is flattened and bounded', async () => {
    const s = await serve((req, res) => {
      req.resume();
      res.writeHead(400);
      res.end(JSON.stringify({ error: 'invalid_grant', error_description: `line1\nline2 ${'x'.repeat(5000)}` }));
    });

    await assert.rejects(
      () => authenticate({ instanceUrl: s.url, clientId: 'cid', clientSecret: 'csec', endpoint: '/e' }),
      (err: unknown) => {
        assert.ok(err instanceof Error);
        assert.ok(!err.message.includes('\n'));
        assert.ok(err.message.length < 600);
        return true;
      }
    );
  });
});
