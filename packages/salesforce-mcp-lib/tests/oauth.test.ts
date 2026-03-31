import { describe, it, before, after, beforeEach } from 'node:test';
import assert from 'node:assert';
import http from 'node:http';
import type { IncomingMessage, ServerResponse } from 'node:http';

import {
  authenticate,
  getToken,
  getInstanceUrl,
  resetTokenCache,
} from '../src/oauth.js';
import { SalesforceAuthError } from '../src/errors.js';
import type { BridgeConfig } from '../src/types.js';

let serverHandler: (req: IncomingMessage, res: ServerResponse) => void;
let server: http.Server;
let baseUrl: string;

before(async () => {
  server = http.createServer((req, res) => serverHandler(req, res));
  await new Promise<void>(resolve => server.listen(0, resolve));
  const addr = server.address() as { port: number };
  baseUrl = `http://localhost:${addr.port}`;
});

after(async () => {
  await new Promise<void>(resolve => server.close(() => resolve()));
});

beforeEach(() => {
  resetTokenCache();
});

function makeConfig(overrides?: Partial<BridgeConfig>): BridgeConfig {
  return {
    instanceUrl: baseUrl,
    clientId: 'test-client-id',
    clientSecret: 'test-client-secret',
    endpoint: '/services/apexrest/mcp',
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// authenticate() — success
// ---------------------------------------------------------------------------
describe('authenticate() - success', () => {
  it('returns valid OAuthTokenResponse on 200', async () => {
    serverHandler = (_req, res) => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(
        JSON.stringify({
          access_token: 'tok_abc',
          instance_url: 'https://my.salesforce.com',
          token_type: 'Bearer',
          id: 'https://login.salesforce.com/id/00D/005',
          issued_at: '1700000000000',
        })
      );
    };

    const result = await authenticate(makeConfig());

    assert.strictEqual(result.access_token, 'tok_abc');
    assert.strictEqual(result.instance_url, 'https://my.salesforce.com');
    assert.strictEqual(result.token_type, 'Bearer');
    assert.strictEqual(result.id, 'https://login.salesforce.com/id/00D/005');
    assert.strictEqual(result.issued_at, '1700000000000');
  });

  it('caches token after auth', async () => {
    serverHandler = (_req, res) => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ access_token: 'cached_tok' }));
    };

    await authenticate(makeConfig());
    assert.strictEqual(getToken(), 'cached_tok');
  });

  it('caches instance URL after auth', async () => {
    serverHandler = (_req, res) => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(
        JSON.stringify({
          access_token: 'tok',
          instance_url: 'https://cached.salesforce.com',
        })
      );
    };

    await authenticate(makeConfig());
    assert.strictEqual(getInstanceUrl(), 'https://cached.salesforce.com');
  });

  it('defaults instance_url to config value when not in response', async () => {
    serverHandler = (_req, res) => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ access_token: 'tok_no_url' }));
    };

    const cfg = makeConfig();
    const result = await authenticate(cfg);
    assert.strictEqual(result.instance_url, cfg.instanceUrl);
  });

  it('defaults token_type to Bearer when not in response', async () => {
    serverHandler = (_req, res) => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ access_token: 'tok_no_type' }));
    };

    const result = await authenticate(makeConfig());
    assert.strictEqual(result.token_type, 'Bearer');
  });

  it('sends correct Content-Type and body', async () => {
    let capturedContentType: string | undefined;
    let capturedBody = '';

    serverHandler = (req, res) => {
      capturedContentType = req.headers['content-type'];
      const chunks: Buffer[] = [];
      req.on('data', (chunk: Buffer) => chunks.push(chunk));
      req.on('end', () => {
        capturedBody = Buffer.concat(chunks).toString('utf-8');
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ access_token: 'tok' }));
      });
    };

    await authenticate(makeConfig());

    assert.strictEqual(capturedContentType, 'application/x-www-form-urlencoded');

    const params = new URLSearchParams(capturedBody);
    assert.strictEqual(params.get('grant_type'), 'client_credentials');
    assert.strictEqual(params.get('client_id'), 'test-client-id');
    assert.strictEqual(params.get('client_secret'), 'test-client-secret');
  });
});

// ---------------------------------------------------------------------------
// authenticate() — errors
// ---------------------------------------------------------------------------
describe('authenticate() - errors', () => {
  it('throws SalesforceAuthError on invalid JSON response', async () => {
    serverHandler = (_req, res) => {
      res.writeHead(200, { 'Content-Type': 'text/plain' });
      res.end('not json');
    };

    await assert.rejects(() => authenticate(makeConfig()), (err: unknown) => {
      assert(err instanceof SalesforceAuthError);
      assert(err.message.includes('not valid JSON'));
      return true;
    });
  });

  it('throws on OAuth error field', async () => {
    serverHandler = (_req, res) => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(
        JSON.stringify({
          error: 'invalid_client',
          error_description: 'bad client',
        })
      );
    };

    await assert.rejects(() => authenticate(makeConfig()), (err: unknown) => {
      assert(err instanceof SalesforceAuthError);
      assert(err.message.includes('invalid_client'));
      assert(err.message.includes('bad client'));
      return true;
    });
  });

  it('throws with "unknown" when no error_description', async () => {
    serverHandler = (_req, res) => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'x' }));
    };

    await assert.rejects(() => authenticate(makeConfig()), (err: unknown) => {
      assert(err instanceof SalesforceAuthError);
      assert(err.message.includes('unknown'));
      return true;
    });
  });

  it('throws when access_token missing', async () => {
    serverHandler = (_req, res) => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ token_type: 'Bearer' }));
    };

    await assert.rejects(() => authenticate(makeConfig()), (err: unknown) => {
      assert(err instanceof SalesforceAuthError);
      assert(err.message.includes('missing access_token'));
      return true;
    });
  });

  it('throws when access_token is not a string', async () => {
    serverHandler = (_req, res) => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ access_token: 123 }));
    };

    await assert.rejects(() => authenticate(makeConfig()), (err: unknown) => {
      assert(err instanceof SalesforceAuthError);
      assert(err.message.includes('missing access_token'));
      return true;
    });
  });

  it('throws on HTTP 401', async () => {
    serverHandler = (_req, res) => {
      res.writeHead(401, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'unauthorized' }));
    };

    await assert.rejects(() => authenticate(makeConfig()), (err: unknown) => {
      assert(err instanceof SalesforceAuthError);
      assert(err.message.includes('401'));
      return true;
    });
  });

  it('throws on HTTP 500', async () => {
    serverHandler = (_req, res) => {
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end('Internal Server Error');
    };

    await assert.rejects(() => authenticate(makeConfig()), (err: unknown) => {
      assert(err instanceof SalesforceAuthError);
      assert(err.message.includes('500'));
      return true;
    });
  });

  it('throws on network error', async () => {
    await assert.rejects(
      () => authenticate(makeConfig({ instanceUrl: 'http://localhost:1' })),
      (err: unknown) => {
        assert(err instanceof SalesforceAuthError);
        assert(err.message.includes('network error'));
        return true;
      }
    );
  });
});

// ---------------------------------------------------------------------------
// getToken / getInstanceUrl / resetTokenCache
// ---------------------------------------------------------------------------
describe('getToken / getInstanceUrl / resetTokenCache', () => {
  it('getToken() returns null before auth', () => {
    assert.strictEqual(getToken(), null);
  });

  it('getInstanceUrl() returns null before auth', () => {
    assert.strictEqual(getInstanceUrl(), null);
  });

  it('resetTokenCache() clears both cached values', async () => {
    serverHandler = (_req, res) => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(
        JSON.stringify({
          access_token: 'tok_to_clear',
          instance_url: 'https://clear.salesforce.com',
        })
      );
    };

    await authenticate(makeConfig());
    assert.strictEqual(getToken(), 'tok_to_clear');
    assert.strictEqual(getInstanceUrl(), 'https://clear.salesforce.com');

    resetTokenCache();

    assert.strictEqual(getToken(), null);
    assert.strictEqual(getInstanceUrl(), null);
  });
});
