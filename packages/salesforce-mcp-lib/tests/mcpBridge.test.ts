import { describe, it, before, after, beforeEach } from 'node:test';
import assert from 'node:assert';
import http from 'node:http';
import type { IncomingMessage, ServerResponse } from 'node:http';

import { createBridge, resolveTarget } from '../src/mcpBridge.js';
import type { Bridge, BridgeLogger, BridgeOutcome } from '../src/mcpBridge.js';
import { classifyLine } from '../src/protocol.js';
import type { ForwardableMessage } from '../src/protocol.js';
import type { AuthStrategy } from '../src/authStrategy.js';
import type { AuthConfig, OAuthTokenResponse } from '../src/types.js';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { ClientCredentialsStrategy, resetTokenCache } from '../src/oauth.js';
import { PerUserAuthStrategy } from '../src/authStrategy.js';
import { loadTokens, saveTokens } from '../src/tokenStore.js';

// ---------------------------------------------------------------------------
// Collecting logger
// ---------------------------------------------------------------------------

function createCollectingLogger() {
  const logs: { level: string; message: string }[] = [];
  return {
    logs,
    debug: (msg: string) => logs.push({ level: 'debug', message: msg }),
    info: (msg: string) => logs.push({ level: 'info', message: msg }),
    warn: (msg: string) => logs.push({ level: 'warn', message: msg }),
    error: (msg: string) => logs.push({ level: 'error', message: msg }),
  };
}

/** Classify a line and forward it; asserts the outcome is a written line. */
async function fwd(bridge: Bridge, line: string): Promise<string> {
  const outcome = await send(bridge, line);
  assert.strictEqual(outcome.kind, 'write', `expected a written line, got ${outcome.kind}`);
  return (outcome as { line: string }).line;
}

function send(bridge: Bridge, line: string, signal?: AbortSignal): Promise<BridgeOutcome> {
  const msg = classifyLine(line);
  assert.ok(msg.kind === 'request' || msg.kind === 'notification', `unforwardable line ${line}`);
  return bridge.forward(msg as ForwardableMessage, signal);
}

// ---------------------------------------------------------------------------
// Mock AuthStrategy for tests
// ---------------------------------------------------------------------------

/**
 * Create a mock AuthStrategy that returns the given token and instance URL.
 * The reauthenticate function calls the provided oauthUrl to simulate re-auth.
 */
function createMockStrategy(opts: {
  token: string | null;
  instanceUrl: string;
  oauthUrl?: string;
  reauthFn?: () => Promise<OAuthTokenResponse>;
}): AuthStrategy {
  let currentToken = opts.token;
  let currentInstanceUrl = opts.instanceUrl;

  return {
    mode: 'client_credentials',
    async getAccessToken(): Promise<string> {
      if (!currentToken) throw new Error('No access token available');
      return currentToken;
    },
    getInstanceUrl(): string | null {
      return currentInstanceUrl;
    },
    async reauthenticate(): Promise<OAuthTokenResponse> {
      if (opts.reauthFn) {
        const response = await opts.reauthFn();
        currentToken = response.access_token;
        currentInstanceUrl = response.instance_url;
        return response;
      }
      // Default: re-auth via oauthUrl
      return new Promise<OAuthTokenResponse>((resolve, reject) => {
        const url = new URL('/services/oauth2/token', opts.oauthUrl ?? opts.instanceUrl);
        const body = 'grant_type=client_credentials&client_id=cid&client_secret=csec';
        const req = http.request(url, { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Content-Length': Buffer.byteLength(body).toString() } }, (res) => {
          const chunks: Buffer[] = [];
          res.on('data', (c: Buffer) => chunks.push(c));
          res.on('end', () => {
            const text = Buffer.concat(chunks).toString('utf-8');
            try {
              const parsed = JSON.parse(text);
              if (parsed.error) {
                reject(new Error(`OAuth error: ${parsed.error}`));
                return;
              }
              currentToken = parsed.access_token;
              currentInstanceUrl = parsed.instance_url;
              resolve(parsed);
            } catch {
              reject(new Error(`Invalid JSON: ${text}`));
            }
          });
        });
        req.on('error', reject);
        req.write(body);
        req.end();
      });
    },
    invalidateToken(): void {
      currentToken = null;
    },
  } as AuthStrategy & { invalidateToken(): void };
}

// ---------------------------------------------------------------------------
// Test infrastructure — two local HTTP servers
// ---------------------------------------------------------------------------

let oauthHandler: (req: IncomingMessage, res: ServerResponse) => void;
let apexHandler: (req: IncomingMessage, res: ServerResponse) => void;
let oauthServer: http.Server;
let apexServer: http.Server;
let oauthUrl: string;
let apexUrl: string;

before(async () => {
  oauthServer = http.createServer((req, res) => oauthHandler(req, res));
  apexServer = http.createServer((req, res) => apexHandler(req, res));
  await Promise.all([
    new Promise<void>(r => oauthServer.listen(0, r)),
    new Promise<void>(r => apexServer.listen(0, r)),
  ]);
  oauthUrl = `http://localhost:${(oauthServer.address() as { port: number }).port}`;
  apexUrl = `http://localhost:${(apexServer.address() as { port: number }).port}`;
});

after(async () => {
  await Promise.all([
    new Promise<void>(r => oauthServer.close(() => r())),
    new Promise<void>(r => apexServer.close(() => r())),
  ]);
});

beforeEach(() => {
  // Default OAuth handler — returns a valid token with instance_url = apexUrl
  oauthHandler = (_req, res) => {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      access_token: 'test-token-abc',
      instance_url: apexUrl,
      token_type: 'Bearer',
      id: 'id',
      issued_at: '123',
    }));
  };

  // Default Apex handler — 200 with echo-like response
  apexHandler = (_req, res) => {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end('{"jsonrpc":"2.0","id":1,"result":"ok"}');
  };
});

function makeConfig(): AuthConfig {
  return {
    instanceUrl: oauthUrl,
    clientId: 'cid',
    clientSecret: 'csec',
    endpoint: '/services/apexrest/mcp',
  };
}

function makeStrategyWithToken(): AuthStrategy {
  return createMockStrategy({
    token: 'test-token-abc',
    instanceUrl: apexUrl,
    oauthUrl,
  });
}

function makeStrategyNoToken(): AuthStrategy {
  return createMockStrategy({
    token: null,
    instanceUrl: apexUrl,
    oauthUrl,
  });
}

// ---------------------------------------------------------------------------
// No cached token
// ---------------------------------------------------------------------------

describe('mcpBridge — no cached token', () => {
  it('returns JSON-RPC error when no cached token', async () => {
    const bridge = createBridge(makeStrategyNoToken(), makeConfig());
    const raw = await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"test"}');
    const parsed = JSON.parse(raw);

    assert.strictEqual(parsed.error.code, -32603);
    assert.ok(
      (parsed.error.message as string).includes('No access token'),
      `Expected message to include "No access token", got: ${parsed.error.message}`
    );
  });

  it('notification without a token is silent', async () => {
    const bridge = createBridge(makeStrategyNoToken(), makeConfig());
    const outcome = await send(bridge, '{"jsonrpc":"2.0","method":"notifications/initialized"}');

    assert.deepStrictEqual(outcome, { kind: 'silent' });
  });

  it('local error carries the proxy marker and the request id', async () => {
    const bridge = createBridge(makeStrategyNoToken(), makeConfig());
    const parsed = JSON.parse(await fwd(bridge, '{"jsonrpc":"2.0","id":7,"method":"test"}'));

    assert.strictEqual(parsed.id, 7);
    assert.deepStrictEqual(parsed.error.data, { source: 'salesforce-mcp-lib-proxy', httpStatus: null });
  });
});

// ---------------------------------------------------------------------------
// Successful forward (HTTP 200)
// ---------------------------------------------------------------------------

describe('mcpBridge — successful forward (HTTP 200)', () => {
  it('returns response body on HTTP 200', async () => {
    const expectedBody = '{"jsonrpc":"2.0","id":1,"result":"ok"}';
    apexHandler = (_req, res) => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(expectedBody);
    };

    const bridge = createBridge(makeStrategyWithToken(), makeConfig());
    const result = await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"test"}');

    assert.strictEqual(result, expectedBody);
  });

  it('sends correct Authorization header', async () => {
    let capturedAuth: string | undefined;
    apexHandler = (req, res) => {
      capturedAuth = req.headers['authorization'];
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end('{"jsonrpc":"2.0","id":1,"result":"ok"}');
    };

    const bridge = createBridge(makeStrategyWithToken(), makeConfig());
    await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"test"}');

    assert.strictEqual(capturedAuth, 'Bearer test-token-abc');
  });

  it('sends Content-Type application/json', async () => {
    let capturedContentType: string | undefined;
    apexHandler = (req, res) => {
      capturedContentType = req.headers['content-type'];
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end('{"jsonrpc":"2.0","id":1,"result":"ok"}');
    };

    const bridge = createBridge(makeStrategyWithToken(), makeConfig());
    await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"test"}');

    assert.strictEqual(capturedContentType, 'application/json');
  });

  it('sends message body unchanged', async () => {
    let capturedBody = '';
    const message = '{"jsonrpc":"2.0","id":1,"method":"tools/list"}';

    apexHandler = (req, res) => {
      const chunks: Buffer[] = [];
      req.on('data', (chunk: Buffer) => chunks.push(chunk));
      req.on('end', () => {
        capturedBody = Buffer.concat(chunks).toString('utf-8');
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end('{"jsonrpc":"2.0","id":1,"result":"ok"}');
      });
    };

    const bridge = createBridge(makeStrategyWithToken(), makeConfig());
    await fwd(bridge, message);

    assert.strictEqual(capturedBody, message);
  });

  it('POSTs to configured endpoint path', async () => {
    let capturedUrl: string | undefined;
    apexHandler = (req, res) => {
      capturedUrl = req.url;
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end('{"jsonrpc":"2.0","id":1,"result":"ok"}');
    };

    const bridge = createBridge(makeStrategyWithToken(), makeConfig());
    await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"test"}');

    assert.strictEqual(capturedUrl, '/services/apexrest/mcp');
  });
});

// ---------------------------------------------------------------------------
// 401 re-authentication
// ---------------------------------------------------------------------------

describe('mcpBridge — 401 re-authentication', () => {
  it('re-auth + retry on 401 INVALID_SESSION_ID', async () => {
    let apexCallCount = 0;
    apexHandler = (_req, res) => {
      apexCallCount++;
      if (apexCallCount === 1) {
        res.writeHead(401, { 'Content-Type': 'application/json' });
        res.end('[{"errorCode":"INVALID_SESSION_ID","message":"Session expired"}]');
      } else {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end('{"jsonrpc":"2.0","id":1,"result":"retried"}');
      }
    };

    oauthHandler = (_req, res) => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        access_token: 'new-token-xyz',
        instance_url: apexUrl,
        token_type: 'Bearer',
        id: 'id',
        issued_at: '456',
      }));
    };

    const bridge = createBridge(makeStrategyWithToken(), makeConfig());
    const raw = await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"test"}');

    assert.strictEqual(raw, '{"jsonrpc":"2.0","id":1,"result":"retried"}');
  });

  it('logger.warn on re-auth attempt', async () => {
    let apexCallCount = 0;
    apexHandler = (_req, res) => {
      apexCallCount++;
      if (apexCallCount === 1) {
        res.writeHead(401, { 'Content-Type': 'application/json' });
        res.end('[{"errorCode":"INVALID_SESSION_ID","message":"Session expired"}]');
      } else {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end('{"jsonrpc":"2.0","id":1,"result":"ok"}');
      }
    };

    const logger = createCollectingLogger();
    const bridge = createBridge(makeStrategyWithToken(), makeConfig(), logger as BridgeLogger);
    await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"test"}');

    const warnLogs = logger.logs.filter(l => l.level === 'warn');
    assert.ok(
      warnLogs.some(l => l.message.includes('INVALID_SESSION_ID')),
      `Expected a warn log about INVALID_SESSION_ID, got: ${JSON.stringify(warnLogs)}`
    );
  });

  it('no re-auth on 401 without INVALID_SESSION_ID', async () => {
    apexHandler = (_req, res) => {
      res.writeHead(401, { 'Content-Type': 'text/plain' });
      res.end('Unauthorized');
    };

    const bridge = createBridge(makeStrategyWithToken(), makeConfig());
    const raw = await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"test"}');
    const parsed = JSON.parse(raw);

    assert.strictEqual(parsed.error.code, -32603);
    assert.ok(
      (parsed.error.message as string).includes('Authorization error'),
      `Expected "Authorization error", got: ${parsed.error.message}`
    );
  });

  it('JSON-RPC error when re-auth fails', async () => {
    apexHandler = (_req, res) => {
      res.writeHead(401, { 'Content-Type': 'application/json' });
      res.end('[{"errorCode":"INVALID_SESSION_ID","message":"Session expired"}]');
    };

    // Strategy that fails on reauthenticate
    const failStrategy = createMockStrategy({
      token: 'test-token-abc',
      instanceUrl: apexUrl,
      reauthFn: async () => {
        throw new Error('re-auth failed');
      },
    });

    const bridge = createBridge(failStrategy, makeConfig());
    const raw = await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"test"}');
    const parsed = JSON.parse(raw);

    assert.strictEqual(parsed.error.code, -32603);
    assert.ok(
      (parsed.error.message as string).includes('re-authentication failed') ||
      (parsed.error.message as string).includes('Session expired'),
      `Expected message about re-auth failure, got: ${parsed.error.message}`
    );
  });

  it('sanitized error when retry returns non-200', async () => {
    let apexCallCount = 0;
    apexHandler = (_req, res) => {
      apexCallCount++;
      if (apexCallCount === 1) {
        res.writeHead(401, { 'Content-Type': 'application/json' });
        res.end('[{"errorCode":"INVALID_SESSION_ID","message":"Session expired"}]');
      } else {
        res.writeHead(500, { 'Content-Type': 'text/plain' });
        res.end('Internal Server Error');
      }
    };

    const bridge = createBridge(makeStrategyWithToken(), makeConfig());
    const raw = await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"test"}');
    const parsed = JSON.parse(raw);

    assert.strictEqual(parsed.error.code, -32603);
    assert.ok(
      (parsed.error.message as string).includes('internal error'),
      `Expected "internal error", got: ${parsed.error.message}`
    );
  });
});

// ---------------------------------------------------------------------------
// HTTP error handling
// ---------------------------------------------------------------------------

describe('mcpBridge — HTTP error handling', () => {
  it('sanitized error for HTTP 500', async () => {
    apexHandler = (_req, res) => {
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end('Detailed Apex Error');
    };

    const bridge = createBridge(makeStrategyWithToken(), makeConfig());
    const raw = await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"test"}');
    const parsed = JSON.parse(raw);

    assert.strictEqual(parsed.error.code, -32603);
    assert.ok(
      (parsed.error.message as string).includes('internal error'),
      `Expected "internal error", got: ${parsed.error.message}`
    );
    assert.ok(
      !(parsed.error.message as string).includes('Detailed Apex Error'),
      'Error message should NOT contain raw Apex error details'
    );
  });

  it('sanitized error for HTTP 403', async () => {
    apexHandler = (_req, res) => {
      res.writeHead(403, { 'Content-Type': 'text/plain' });
      res.end('Forbidden');
    };

    const bridge = createBridge(makeStrategyWithToken(), makeConfig());
    const raw = await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"test"}');
    const parsed = JSON.parse(raw);

    assert.strictEqual(parsed.error.code, -32603);
    assert.ok(
      (parsed.error.message as string).includes('Authorization error'),
      `Expected "Authorization error", got: ${parsed.error.message}`
    );
  });

  it('sanitized error for unexpected status (503)', async () => {
    apexHandler = (_req, res) => {
      res.writeHead(503, { 'Content-Type': 'text/plain' });
      res.end('Service Unavailable');
    };

    const bridge = createBridge(makeStrategyWithToken(), makeConfig());
    const raw = await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"test"}');
    const parsed = JSON.parse(raw);

    assert.strictEqual(parsed.error.code, -32603);
    assert.ok(
      (parsed.error.message as string).includes('unexpected status'),
      `Expected "unexpected status", got: ${parsed.error.message}`
    );
    assert.ok(
      (parsed.error.message as string).includes('HTTP 503'),
      `Expected "HTTP 503", got: ${parsed.error.message}`
    );
  });
});

// ---------------------------------------------------------------------------
// Request ID extraction
// ---------------------------------------------------------------------------

describe('mcpBridge — request ID extraction', () => {
  it('echoes numeric request ID', async () => {
    apexHandler = (_req, res) => {
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end('error');
    };

    const bridge = createBridge(makeStrategyWithToken(), makeConfig());
    const raw = await fwd(bridge, '{"jsonrpc":"2.0","id":42,"method":"test"}');
    const parsed = JSON.parse(raw);

    assert.strictEqual(parsed.id, 42);
  });

  it('echoes string request ID', async () => {
    apexHandler = (_req, res) => {
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end('error');
    };

    const bridge = createBridge(makeStrategyWithToken(), makeConfig());
    const raw = await fwd(bridge, '{"jsonrpc":"2.0","id":"abc-123","method":"test"}');
    const parsed = JSON.parse(raw);

    assert.strictEqual(parsed.id, 'abc-123');
  });
});

// ---------------------------------------------------------------------------
// Network errors
// ---------------------------------------------------------------------------

describe('mcpBridge — network errors', () => {
  it('network error on the first attempt becomes a local error', async () => {
    const badStrategy = createMockStrategy({
      token: 'test-token-abc',
      instanceUrl: 'http://localhost:1',
      oauthUrl,
    });

    const bridge = createBridge(badStrategy, makeConfig());
    const parsed = JSON.parse(await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"test"}'));

    assert.strictEqual(parsed.id, 1);
    assert.strictEqual(parsed.error.data.httpStatus, null);
  });
});

// ---------------------------------------------------------------------------
// v2 wire contract (spec C3 7.2 / 7.3)
// ---------------------------------------------------------------------------

const MODERN_REQUEST =
  '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"Hello, 世界","_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28","io.modelcontextprotocol/clientCapabilities":{}}}}';

function captureHeaders(): { seen: http.IncomingHttpHeaders[] } {
  const capture = { seen: [] as http.IncomingHttpHeaders[] };
  apexHandler = (req, res) => {
    capture.seen.push(req.headers);
    req.resume();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end('{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-11-25"}}');
  };
  return capture;
}

describe('mcpBridge — outbound headers', () => {
  it('sends modern protocol headers and an encoded Mcp-Name, leaving the body untouched', async () => {
    const capture = captureHeaders();
    const bridge = createBridge(makeStrategyWithToken(), makeConfig());
    await fwd(bridge, MODERN_REQUEST);

    const h = capture.seen[0]!;
    assert.strictEqual(h['mcp-protocol-version'], '2026-07-28');
    assert.strictEqual(h['mcp-method'], 'tools/call');
    assert.strictEqual(h['mcp-name'], `=?base64?${Buffer.from('Hello, 世界').toString('base64')}?=`);
    assert.strictEqual(h['accept'], 'application/json, text/event-stream');
  });

  it('sends no protocol headers on initialize, then the legacy version afterwards', async () => {
    const capture = captureHeaders();
    const bridge = createBridge(makeStrategyWithToken(), makeConfig());
    await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25"}}');
    await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"tools/list"}');

    assert.strictEqual(capture.seen[0]!['mcp-protocol-version'], undefined);
    assert.strictEqual(capture.seen[1]!['mcp-protocol-version'], '2025-11-25');
  });

  it('modern requests never use the legacy version', async () => {
    const capture = captureHeaders();
    const bridge = createBridge(makeStrategyWithToken(), makeConfig());
    await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"initialize"}');
    await fwd(bridge, MODERN_REQUEST);

    assert.strictEqual(capture.seen[1]!['mcp-protocol-version'], '2026-07-28');
  });

  it('rejects a modern method that is not header-safe without sending', async () => {
    const capture = captureHeaders();
    const bridge = createBridge(makeStrategyWithToken(), makeConfig());
    const line = JSON.stringify({
      jsonrpc: '2.0', id: 1, method: 'tools/cäll',
      params: { _meta: { 'io.modelcontextprotocol/protocolVersion': '2026-07-28' } },
    });
    const parsed = JSON.parse(await fwd(bridge, line));

    assert.strictEqual(parsed.error.code, -32600);
    assert.ok(!('data' in parsed.error), 'a client request error is not a proxy fault');
    assert.strictEqual(parsed.id, 1);
    assert.strictEqual(capture.seen.length, 0);
  });

  it('rejects a malformed modern version with -32600, never sending the legacy version', async () => {
    const capture = captureHeaders();
    const bridge = createBridge(makeStrategyWithToken(), makeConfig());
    await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25"}}');
    capture.seen.length = 0;
    for (const bad of ['5', 'null', '"2026 07 28"', '""']) {
      const line = `{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":${bad}}}}`;
      const parsed = JSON.parse(await fwd(bridge, line));
      assert.strictEqual(parsed.error.code, -32600, bad);
      assert.strictEqual(parsed.id, 2);
    }
    assert.strictEqual(capture.seen.length, 0);
  });

  it('a rejected header does not touch authentication', async () => {
    let tokenCalls = 0;
    const strategy = makeStrategyWithToken();
    const original = strategy.getAccessToken.bind(strategy);
    strategy.getAccessToken = () => (tokenCalls++, original());
    const bridge = createBridge(strategy, makeConfig());
    await fwd(bridge, '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":7}}}');

    assert.strictEqual(tokenCalls, 0);
  });

  it('a header-invalid notification is silent', async () => {
    const bridge = createBridge(makeStrategyWithToken(), makeConfig());
    const outcome = await send(bridge, '{"jsonrpc":"2.0","method":"notifications/x","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":7}}}');

    assert.deepStrictEqual(outcome, { kind: 'silent' });
  });
});

describe('mcpBridge — lossless remote bodies (M2)', () => {
  it('forwards numbers verbatim from a multi-line body', async () => {
    apexHandler = (_req, res) => {
      _req.resume();
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end('{\n  "jsonrpc": "2.0",\n  "id": 1,\n  "result": {"n": [12345678901234567890, 0.1000000000000000055511151231257827, 1e999], "s": "a  b"}\n}\n');
    };
    const bridge = createBridge(makeStrategyWithToken(), makeConfig());
    const line = await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"tools/list"}');

    assert.strictEqual(
      line,
      '{"jsonrpc":"2.0","id":1,"result":{"n":[12345678901234567890,0.1000000000000000055511151231257827,1e999],"s":"a  b"}}'
    );
  });

  it('keeps error.data numbers when it injects the id', async () => {
    apexHandler = (_req, res) => {
      _req.resume();
      res.writeHead(400);
      res.end('{"jsonrpc":"2.0","error":{"code":-32600,"message":"m","data":{"n":12345678901234567890}}}');
    };
    const bridge = createBridge(makeStrategyWithToken(), makeConfig());
    const line = await fwd(bridge, '{"jsonrpc":"2.0","id":"a","method":"x"}');

    assert.strictEqual(line, '{"id":"a","jsonrpc":"2.0","error":{"code":-32600,"message":"m","data":{"n":12345678901234567890}}}');
  });
});

describe('mcpBridge — remote response interpretation', () => {
  it('notification 202 is silent', async () => {
    apexHandler = (req, res) => {
      req.resume();
      res.writeHead(202);
      res.end();
    };
    const bridge = createBridge(makeStrategyWithToken(), makeConfig());
    const outcome = await send(bridge, '{"jsonrpc":"2.0","method":"notifications/initialized"}');

    assert.deepStrictEqual(outcome, { kind: 'silent' });
  });

  it('notification errors stay silent and are only logged', async () => {
    apexHandler = (_req, res) => {
      res.writeHead(500);
      res.end('secret remote body');
    };
    const logger = createCollectingLogger();
    const bridge = createBridge(makeStrategyWithToken(), makeConfig(), logger as BridgeLogger);
    const outcome = await send(bridge, '{"jsonrpc":"2.0","method":"notifications/initialized"}');

    assert.deepStrictEqual(outcome, { kind: 'silent' });
    assert.ok(logger.logs.some((l) => l.level === 'warn' && l.message.includes('HTTP 500')));
    assert.ok(logger.logs.every((l) => !l.message.includes('secret remote body')));
  });

  for (const status of [202, 204]) {
    it(`request answered with empty ${status} becomes a local error, not a hang`, async () => {
      apexHandler = (_req, res) => {
        res.writeHead(status);
        res.end();
      };
      const bridge = createBridge(makeStrategyWithToken(), makeConfig());
      const parsed = JSON.parse(await fwd(bridge, '{"jsonrpc":"2.0","id":3,"method":"tools/list"}'));

      assert.strictEqual(parsed.id, 3);
      assert.strictEqual(parsed.error.data.httpStatus, status);
    });
  }

  it('forwards a modern 400 -32022 envelope unchanged', async () => {
    const envelope = '{"jsonrpc":"2.0","id":1,"error":{"code":-32022,"message":"Unsupported","data":{"supported":["2026-07-28","2025-11-25"]}}}';
    apexHandler = (_req, res) => {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(envelope);
    };
    const bridge = createBridge(makeStrategyWithToken(), makeConfig());

    assert.strictEqual(await fwd(bridge, MODERN_REQUEST), envelope);
  });

  it('forwards a 404 -32601 envelope', async () => {
    const envelope = '{"jsonrpc":"2.0","id":1,"error":{"code":-32601,"message":"Method not found"}}';
    apexHandler = (_req, res) => {
      res.writeHead(404, { 'Content-Type': 'application/json' });
      res.end(envelope);
    };
    const bridge = createBridge(makeStrategyWithToken(), makeConfig());

    assert.strictEqual(await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"nope"}'), envelope);
  });

  it('turns a Salesforce error array on 500 into a local error without the body', async () => {
    apexHandler = (_req, res) => {
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end('[{"errorCode":"APEX_ERROR","message":"System.LimitException: Apex heap"}]');
    };
    const bridge = createBridge(makeStrategyWithToken(), makeConfig());
    const line = await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"tools/list"}');

    assert.ok(!line.includes('LimitException'));
    assert.strictEqual(JSON.parse(line).error.data.httpStatus, 500);
  });

  it('re-serializes a multi-line body to one line', async () => {
    apexHandler = (_req, res) => {
      res.writeHead(200);
      res.end('{\n  "jsonrpc": "2.0",\n  "id": 1,\n  "result": {"a": "x\\ny"}\n}\n');
    };
    const bridge = createBridge(makeStrategyWithToken(), makeConfig());
    const line = await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"tools/list"}');

    assert.ok(!line.includes('\n'));
    assert.deepStrictEqual(JSON.parse(line).result, { a: 'x\ny' });
  });

  for (const [name, body] of [
    ['mismatched id', '{"jsonrpc":"2.0","id":2,"result":{}}'],
    ['string id for numeric request', '{"jsonrpc":"2.0","id":"1","result":{}}'],
    ['result without id', '{"jsonrpc":"2.0","result":{}}'],
    ['both result and error', '{"jsonrpc":"2.0","id":1,"result":{},"error":{"code":-1,"message":"x"}}'],
    ['neither result nor error', '{"jsonrpc":"2.0","id":1}'],
    ['wrong jsonrpc', '{"jsonrpc":"1.0","id":1,"result":{}}'],
    ['error with non-integer code', '{"jsonrpc":"2.0","id":1,"error":{"code":1.5,"message":"x"}}'],
  ] as const) {
    it(`rejects ${name}`, async () => {
      apexHandler = (_req, res) => {
        res.writeHead(200);
        res.end(body);
      };
      const bridge = createBridge(makeStrategyWithToken(), makeConfig());
      const parsed = JSON.parse(await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'));

      assert.strictEqual(parsed.error.data.source, 'salesforce-mcp-lib-proxy');
      assert.strictEqual(parsed.id, 1);
    });
  }

  it('attaches the request id to a remote error that has none', async () => {
    apexHandler = (_req, res) => {
      res.writeHead(400);
      res.end('{"jsonrpc":"2.0","error":{"code":-32600,"message":"Invalid Request"}}');
    };
    const bridge = createBridge(makeStrategyWithToken(), makeConfig());
    const parsed = JSON.parse(await fwd(bridge, '{"jsonrpc":"2.0","id":"a","method":"x"}'));

    assert.deepStrictEqual(parsed, { jsonrpc: '2.0', error: { code: -32600, message: 'Invalid Request' }, id: 'a' });
  });
});

describe('mcpBridge — bounds', () => {
  it('times out a silent server with a local error', async () => {
    apexHandler = () => {
      /* never answer */
    };
    const bridge = createBridge(makeStrategyWithToken(), { ...makeConfig(), requestTimeoutMs: 100 });
    const parsed = JSON.parse(await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'));

    assert.ok((parsed.error.message as string).includes('timed out'));
  });

  it('bounds a hanging getAccessToken by the same deadline', async () => {
    const strategy: AuthStrategy = {
      mode: 'client_credentials',
      getAccessToken: () => new Promise<string>(() => {}),
      getInstanceUrl: () => apexUrl,
      reauthenticate: () => new Promise<OAuthTokenResponse>(() => {}),
    };
    const bridge = createBridge(strategy, { ...makeConfig(), requestTimeoutMs: 100 });
    const parsed = JSON.parse(await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'));

    assert.ok((parsed.error.message as string).includes('timed out'));
  });

  it('bounds a hanging re-authentication by the same deadline', async () => {
    apexHandler = (_req, res) => {
      res.writeHead(401);
      res.end('[{"errorCode":"INVALID_SESSION_ID"}]');
    };
    const strategy = createMockStrategy({
      token: 'test-token-abc',
      instanceUrl: apexUrl,
      reauthFn: () => new Promise<OAuthTokenResponse>(() => {}),
    });
    const bridge = createBridge(strategy, { ...makeConfig(), requestTimeoutMs: 150 });
    const parsed = JSON.parse(await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'));

    assert.ok((parsed.error.message as string).includes('timed out'));
  });

  it('aborts when the remote body exceeds 8 MiB (declared length)', async () => {
    apexHandler = (_req, res) => {
      res.writeHead(200);
      res.end(Buffer.alloc(8 * 1024 * 1024 + 1, 0x61));
    };
    const bridge = createBridge(makeStrategyWithToken(), makeConfig());
    const parsed = JSON.parse(await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'));

    assert.ok((parsed.error.message as string).includes('8 MiB'));
  });

  it('aborts when a chunked body exceeds 8 MiB', async () => {
    apexHandler = (_req, res) => {
      res.writeHead(200);
      const chunk = Buffer.alloc(1024 * 1024, 0x61);
      for (let i = 0; i < 9; i++) res.write(chunk);
      res.end();
    };
    const bridge = createBridge(makeStrategyWithToken(), makeConfig());
    const parsed = JSON.parse(await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'));

    assert.ok((parsed.error.message as string).includes('8 MiB'));
  });
});

describe('mcpBridge — cancellation', () => {
  it('aborts the in-flight HTTP request and stays silent', async () => {
    let closed = false;
    let arrived: () => void = () => {};
    const gotRequest = new Promise<void>((r) => (arrived = r));
    apexHandler = (req, res) => {
      res.on('close', () => (closed = true));
      req.resume();
      arrived();
    };
    const ac = new AbortController();
    const bridge = createBridge(makeStrategyWithToken(), makeConfig());
    const pending = send(bridge, '{"jsonrpc":"2.0","id":1,"method":"tools/call"}', ac.signal);
    await gotRequest;
    ac.abort();

    assert.deepStrictEqual(await pending, { kind: 'silent' });
    await new Promise((r) => setTimeout(r, 20));
    assert.ok(closed, 'server should see the connection drop');
  });

  it('a pre-aborted signal sends nothing', async () => {
    const capture = captureHeaders();
    const ac = new AbortController();
    ac.abort();
    const bridge = createBridge(makeStrategyWithToken(), makeConfig());

    assert.deepStrictEqual(await send(bridge, '{"jsonrpc":"2.0","id":1,"method":"x"}', ac.signal), { kind: 'silent' });
    assert.strictEqual(capture.seen.length, 0);
  });

  it('cancelling during re-authentication suppresses the retry', async () => {
    let apexCalls = 0;
    apexHandler = (_req, res) => {
      apexCalls++;
      res.writeHead(401);
      res.end('[{"errorCode":"INVALID_SESSION_ID"}]');
    };
    const ac = new AbortController();
    const strategy = createMockStrategy({
      token: 'test-token-abc',
      instanceUrl: apexUrl,
      reauthFn: async () => {
        ac.abort();
        return { access_token: 'n', instance_url: apexUrl, token_type: 'Bearer', id: '', issued_at: '1' };
      },
    });
    const bridge = createBridge(strategy, makeConfig());

    assert.deepStrictEqual(await send(bridge, '{"jsonrpc":"2.0","id":1,"method":"x"}', ac.signal), { kind: 'silent' });
    assert.strictEqual(apexCalls, 1);
  });
});

// ---------------------------------------------------------------------------
// Token transmission safety
// ---------------------------------------------------------------------------

describe('mcpBridge — token transmission', () => {
  it('does not follow a redirect, so the token never reaches another origin', async () => {
    let otherSeen = 0;
    const other = http.createServer((req, res) => {
      otherSeen++;
      req.resume();
      res.end('{}');
    });
    await new Promise<void>((r) => other.listen(0, r));
    const otherUrl = `http://localhost:${(other.address() as { port: number }).port}/steal`;
    apexHandler = (_req, res) => {
      res.writeHead(307, { Location: otherUrl });
      res.end();
    };
    try {
      const bridge = createBridge(makeStrategyWithToken(), makeConfig());
      const parsed = JSON.parse(await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"x"}'));

      assert.strictEqual(parsed.error.data.httpStatus, 307);
      assert.strictEqual(otherSeen, 0);
    } finally {
      await new Promise<void>((r) => other.close(() => r()));
    }
  });

  for (const endpoint of ['http://evil.example/x', '//evil.example/x', '/\\evil.example/x', 'services/apexrest/mcp']) {
    it(`refuses endpoint ${JSON.stringify(endpoint)} without contacting anyone`, async () => {
      const capture = captureHeaders();
      const bridge = createBridge(makeStrategyWithToken(), { ...makeConfig(), endpoint });
      const parsed = JSON.parse(await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"x"}'));

      assert.strictEqual(parsed.error.code, -32603);
      assert.strictEqual(capture.seen.length, 0);
      assert.ok(!JSON.stringify(parsed).includes('test-token-abc'));
    });
  }

  it('refuses credentials in the instance URL', async () => {
    const strategy = createMockStrategy({ token: 'test-token-abc', instanceUrl: apexUrl.replace('http://', 'http://user:pw@'), oauthUrl });
    const bridge = createBridge(strategy, makeConfig());
    const line = await fwd(bridge, '{"jsonrpc":"2.0","id":1,"method":"x"}');

    assert.ok(!line.includes('pw'));
    assert.strictEqual(JSON.parse(line).error.code, -32603);
  });

  it('resolveTarget requires https except for loopback, and keeps custom domains valid', () => {
    assert.strictEqual(resolveTarget('https://acme.my.salesforce.com', '/services/apexrest/mcp').href, 'https://acme.my.salesforce.com/services/apexrest/mcp');
    assert.strictEqual(resolveTarget('https://acme.example.org', '/mcp').host, 'acme.example.org');
    assert.strictEqual(resolveTarget('http://127.0.0.1:8080', '/mcp').port, '8080');
    assert.throws(() => resolveTarget('http://acme.my.salesforce.com', '/mcp'), /https/);
    assert.throws(() => resolveTarget('https://u:p@acme.my.salesforce.com', '/mcp'), /credentials/);
  });
});

// ---------------------------------------------------------------------------
// Auth coalescing under parallel 401s (H2) and shared waiters (M1)
// ---------------------------------------------------------------------------

const quietLogger = { debug() {}, info() {}, warn() {}, error() {} };
const sleep = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));

/** Apex mock: 401 INVALID_SESSION_ID for the given bearer tokens, otherwise echoes the request id. */
function apexRejecting(stale: Set<string>, seenTokens: string[]): void {
  apexHandler = (req, res) => {
    const chunks: Buffer[] = [];
    req.on('data', (c: Buffer) => chunks.push(c));
    req.on('end', () => {
      const bearer = String(req.headers['authorization']);
      seenTokens.push(bearer);
      if (stale.has(bearer)) {
        res.writeHead(401, { 'Content-Type': 'application/json' });
        res.end('[{"errorCode":"INVALID_SESSION_ID"}]');
        return;
      }
      const id = JSON.parse(Buffer.concat(chunks).toString('utf8')).id;
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ jsonrpc: '2.0', id, result: { bearer } }));
    });
  };
}

const lineFor = (id: number): string => `{"jsonrpc":"2.0","id":${id},"method":"tools/list"}`;

describe('mcpBridge — parallel 401 with client credentials', () => {
  it('four concurrent requests cause one initial and one re-authentication, and a late 401 adds none', async () => {
    resetTokenCache();
    let issued = 0;
    oauthHandler = (req, res) => {
      req.resume();
      const token = `tok-${++issued}`;
      setTimeout(() => {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ access_token: token, instance_url: apexUrl, token_type: 'Bearer', id: 'id', issued_at: '1' }));
      }, 40);
    };
    const seen: string[] = [];
    apexRejecting(new Set(['Bearer tok-1']), seen);
    const strategy = new ClientCredentialsStrategy({ ...makeConfig(), clientSecret: 'csec' }, quietLogger);
    const bridge = createBridge(strategy, makeConfig());

    const results = await Promise.all([1, 2, 3, 4].map((i) => fwd(bridge, lineFor(i))));

    results.forEach((line, i) => {
      const parsed = JSON.parse(line);
      assert.strictEqual(parsed.id, i + 1);
      assert.strictEqual(parsed.result.bearer, 'Bearer tok-2');
    });
    assert.strictEqual(issued, 2, 'one acquisition and one refresh, not one per request');

    // A 401 that arrives late for the already replaced token.
    const late = await strategy.reauthenticate('tok-1');
    assert.strictEqual(late.access_token, 'tok-2');
    assert.strictEqual(issued, 2);
    assert.strictEqual(await strategy.getAccessToken(), 'tok-2');
  });

  it('cancelling one waiter does not abort the shared token request for the others', async () => {
    resetTokenCache();
    let hits = 0;
    oauthHandler = (req, res) => {
      req.resume();
      hits++;
      setTimeout(() => {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ access_token: 'tok-shared', instance_url: apexUrl, token_type: 'Bearer', id: 'id', issued_at: '1' }));
      }, 150);
    };
    apexRejecting(new Set(), []);
    const strategy = new ClientCredentialsStrategy({ ...makeConfig(), clientSecret: 'csec' }, quietLogger);
    const bridge = createBridge(strategy, makeConfig());
    const cancelled = new AbortController();

    const first = send(bridge, lineFor(1), cancelled.signal);
    const second = fwd(bridge, lineFor(2));
    await sleep(30);
    cancelled.abort();

    assert.deepStrictEqual(await first, { kind: 'silent' });
    assert.strictEqual(JSON.parse(await second).result.bearer, 'Bearer tok-shared');
    assert.strictEqual(hits, 1);
  });
});

describe('mcpBridge — parallel 401 with a rotating refresh token', () => {
  let tmpDir: string;
  let savedEnv: string | undefined;

  before(() => {
    savedEnv = process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'];
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sfmcp-bridge-'));
    process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'] = tmpDir;
  });
  after(() => {
    if (savedEnv === undefined) delete process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'];
    else process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'] = savedEnv;
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('redeems the refresh token once, keeps the new tokens on disk, and ignores a late 401', async () => {
    saveTokens(oauthUrl, 'cid', {
      accessToken: 'A1', refreshToken: 'R1', instanceUrl: apexUrl, tokenType: 'Bearer', issuedAt: 1, identityUrl: 'id',
    });
    let validRefresh = 'R1';
    let redemptions = 0;
    let rejected = 0;
    oauthHandler = (req, res) => {
      const chunks: Buffer[] = [];
      req.on('data', (c: Buffer) => chunks.push(c));
      req.on('end', () => {
        const form = new URLSearchParams(Buffer.concat(chunks).toString('utf8'));
        setTimeout(() => {
          if (form.get('refresh_token') !== validRefresh) {
            rejected++;
            res.writeHead(400, { 'Content-Type': 'application/json' });
            res.end('{"error":"invalid_grant","error_description":"expired access/refresh token"}');
            return;
          }
          redemptions++;
          validRefresh = `R${redemptions + 1}`;
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({
            access_token: `A${redemptions + 1}`, refresh_token: validRefresh,
            instance_url: apexUrl, token_type: 'Bearer', id: 'id', issued_at: '2',
          }));
        }, 40);
      });
    };
    apexRejecting(new Set(['Bearer A1']), []);
    const strategy = new PerUserAuthStrategy(
      { instanceUrl: oauthUrl, clientId: 'cid', endpoint: '/services/apexrest/mcp' },
      quietLogger,
      { allowInteractiveLogin: false }
    );
    const bridge = createBridge(strategy, makeConfig());

    const results = await Promise.all([1, 2, 3, 4].map((i) => fwd(bridge, lineFor(i))));

    for (const line of results) assert.strictEqual(JSON.parse(line).result.bearer, 'Bearer A2');
    assert.strictEqual(redemptions, 1);
    assert.strictEqual(rejected, 0, 'no second redemption of the rotated refresh token');
    const stored = loadTokens(oauthUrl, 'cid');
    assert.ok(stored.status === 'loaded' && stored.data.accessToken === 'A2' && stored.data.refreshToken === 'R2');

    const late = await strategy.reauthenticate('A1');
    assert.strictEqual(late.access_token, 'A2');
    assert.strictEqual(redemptions, 1);
    assert.strictEqual(rejected, 0);
    const after = loadTokens(oauthUrl, 'cid');
    assert.ok(after.status === 'loaded' && after.data.accessToken === 'A2', 'a stale failure must not wipe valid tokens');
  });
});
