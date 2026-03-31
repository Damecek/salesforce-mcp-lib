import { describe, it, before, after, beforeEach } from 'node:test';
import assert from 'node:assert';
import http from 'node:http';
import type { IncomingMessage, ServerResponse } from 'node:http';

import { createBridge } from '../src/mcpBridge.js';
import type { BridgeLogger } from '../src/mcpBridge.js';
import { authenticate, resetTokenCache } from '../src/oauth.js';
import type { BridgeConfig } from '../src/types.js';

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
  resetTokenCache();

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

function makeConfig(): BridgeConfig {
  return {
    instanceUrl: oauthUrl,
    clientId: 'cid',
    clientSecret: 'csec',
    endpoint: '/services/apexrest/mcp',
  };
}

// ---------------------------------------------------------------------------
// No cached token
// ---------------------------------------------------------------------------

describe('mcpBridge — no cached token', () => {
  it('returns JSON-RPC error when no cached token', async () => {
    const bridge = createBridge(makeConfig());
    const raw = await bridge.forward('{"jsonrpc":"2.0","id":1,"method":"test"}');
    const parsed = JSON.parse(raw);

    assert.strictEqual(parsed.error.code, -32603);
    assert.ok(
      (parsed.error.message as string).includes('No access token'),
      `Expected message to include "No access token", got: ${parsed.error.message}`
    );
  });

  it('error has null id when message has no id', async () => {
    const bridge = createBridge(makeConfig());
    const raw = await bridge.forward('{"jsonrpc":"2.0","method":"test"}');
    const parsed = JSON.parse(raw);

    assert.strictEqual(parsed.id, null);
  });

  it('error has null id for invalid JSON message', async () => {
    const bridge = createBridge(makeConfig());
    const raw = await bridge.forward('not json');
    const parsed = JSON.parse(raw);

    assert.strictEqual(parsed.id, null);
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

    await authenticate(makeConfig());
    const bridge = createBridge(makeConfig());
    const result = await bridge.forward('{"jsonrpc":"2.0","id":1,"method":"test"}');

    assert.strictEqual(result, expectedBody);
  });

  it('sends correct Authorization header', async () => {
    let capturedAuth: string | undefined;
    apexHandler = (req, res) => {
      capturedAuth = req.headers['authorization'];
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end('{"jsonrpc":"2.0","id":1,"result":"ok"}');
    };

    await authenticate(makeConfig());
    const bridge = createBridge(makeConfig());
    await bridge.forward('{"jsonrpc":"2.0","id":1,"method":"test"}');

    assert.strictEqual(capturedAuth, 'Bearer test-token-abc');
  });

  it('sends Content-Type application/json', async () => {
    let capturedContentType: string | undefined;
    apexHandler = (req, res) => {
      capturedContentType = req.headers['content-type'];
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end('{"jsonrpc":"2.0","id":1,"result":"ok"}');
    };

    await authenticate(makeConfig());
    const bridge = createBridge(makeConfig());
    await bridge.forward('{"jsonrpc":"2.0","id":1,"method":"test"}');

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

    await authenticate(makeConfig());
    const bridge = createBridge(makeConfig());
    await bridge.forward(message);

    assert.strictEqual(capturedBody, message);
  });

  it('POSTs to configured endpoint path', async () => {
    let capturedUrl: string | undefined;
    apexHandler = (req, res) => {
      capturedUrl = req.url;
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end('{"jsonrpc":"2.0","id":1,"result":"ok"}');
    };

    await authenticate(makeConfig());
    const bridge = createBridge(makeConfig());
    await bridge.forward('{"jsonrpc":"2.0","id":1,"method":"test"}');

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

    await authenticate(makeConfig());
    const bridge = createBridge(makeConfig());
    const raw = await bridge.forward('{"jsonrpc":"2.0","id":1,"method":"test"}');

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
    await authenticate(makeConfig());
    const bridge = createBridge(makeConfig(), logger as BridgeLogger);
    await bridge.forward('{"jsonrpc":"2.0","id":1,"method":"test"}');

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

    await authenticate(makeConfig());
    const bridge = createBridge(makeConfig());
    const raw = await bridge.forward('{"jsonrpc":"2.0","id":1,"method":"test"}');
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

    // First authenticate succeeds, then re-auth (triggered by bridge) fails.
    let oauthCallCount = 0;
    oauthHandler = (_req, res) => {
      oauthCallCount++;
      if (oauthCallCount === 1) {
        // Initial authenticate()
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          access_token: 'test-token-abc',
          instance_url: apexUrl,
          token_type: 'Bearer',
          id: 'id',
          issued_at: '123',
        }));
      } else {
        // Re-auth attempt — fails
        res.writeHead(401, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'invalid_client' }));
      }
    };

    await authenticate(makeConfig());
    const bridge = createBridge(makeConfig());
    const raw = await bridge.forward('{"jsonrpc":"2.0","id":1,"method":"test"}');
    const parsed = JSON.parse(raw);

    assert.strictEqual(parsed.error.code, -32603);
    assert.ok(
      (parsed.error.message as string).includes('Session expired and re-authentication failed'),
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

    await authenticate(makeConfig());
    const bridge = createBridge(makeConfig());
    const raw = await bridge.forward('{"jsonrpc":"2.0","id":1,"method":"test"}');
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

    await authenticate(makeConfig());
    const bridge = createBridge(makeConfig());
    const raw = await bridge.forward('{"jsonrpc":"2.0","id":1,"method":"test"}');
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

    await authenticate(makeConfig());
    const bridge = createBridge(makeConfig());
    const raw = await bridge.forward('{"jsonrpc":"2.0","id":1,"method":"test"}');
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

    await authenticate(makeConfig());
    const bridge = createBridge(makeConfig());
    const raw = await bridge.forward('{"jsonrpc":"2.0","id":1,"method":"test"}');
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

    await authenticate(makeConfig());
    const bridge = createBridge(makeConfig());
    const raw = await bridge.forward('{"jsonrpc":"2.0","id":42,"method":"test"}');
    const parsed = JSON.parse(raw);

    assert.strictEqual(parsed.id, 42);
  });

  it('echoes string request ID', async () => {
    apexHandler = (_req, res) => {
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end('error');
    };

    await authenticate(makeConfig());
    const bridge = createBridge(makeConfig());
    const raw = await bridge.forward('{"jsonrpc":"2.0","id":"abc-123","method":"test"}');
    const parsed = JSON.parse(raw);

    assert.strictEqual(parsed.id, 'abc-123');
  });

  it('null id for notifications (no id field)', async () => {
    apexHandler = (_req, res) => {
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end('error');
    };

    await authenticate(makeConfig());
    const bridge = createBridge(makeConfig());
    const raw = await bridge.forward('{"jsonrpc":"2.0","method":"test"}');
    const parsed = JSON.parse(raw);

    assert.strictEqual(parsed.id, null);
  });
});

// ---------------------------------------------------------------------------
// Network errors
// ---------------------------------------------------------------------------

describe('mcpBridge — network errors', () => {
  it('rejects on network error (first attempt)', async () => {
    // Authenticate with instance_url pointing to a closed port
    oauthHandler = (_req, res) => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        access_token: 'test-token-abc',
        instance_url: 'http://localhost:1',
        token_type: 'Bearer',
        id: 'id',
        issued_at: '123',
      }));
    };

    await authenticate(makeConfig());
    const bridge = createBridge(makeConfig());

    await assert.rejects(
      () => bridge.forward('{"jsonrpc":"2.0","id":1,"method":"test"}')
    );
  });
});
