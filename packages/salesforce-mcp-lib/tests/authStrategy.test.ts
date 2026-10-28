import { after, afterEach, before, beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import http from 'node:http';
import path from 'node:path';

import {
  PerUserAuthStrategy,
  createAuthStrategy,
  type AuthStrategy,
} from '../src/authStrategy.js';
import { ClientCredentialsStrategy } from '../src/oauth.js';
import { LoginRequiredError, SessionExpiredError } from '../src/errors.js';
import { loadTokens, saveTokens } from '../src/tokenStore.js';
import type {
  AuthConfig,
  OAuthTokenResponse,
  PerUserTokenData,
} from '../src/types.js';

const logger = {
  debug: () => {},
  info: () => {},
  warn: () => {},
  error: () => {},
};

function makeConfig(overrides?: Partial<AuthConfig>): AuthConfig {
  return {
    instanceUrl: 'https://test.salesforce.com',
    clientId: 'test-client-id',
    endpoint: '/services/apexrest/mcp',
    logLevel: 'info',
    ...overrides,
  };
}

function makeTokenData(overrides?: Partial<PerUserTokenData>): PerUserTokenData {
  return {
    accessToken: 'stored-access-token',
    refreshToken: 'stored-refresh-token',
    instanceUrl: 'https://test.salesforce.com',
    tokenType: 'Bearer',
    issuedAt: 1700000000000,
    identityUrl: 'https://login.salesforce.com/id/00Dxx/005xx',
    ...overrides,
  };
}

describe('createAuthStrategy per-user interactive policy', () => {
  let savedEnv: string | undefined;
  let tmpDir: string;

  beforeEach(() => {
    savedEnv = process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'];
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sfmcp-auth-'));
    process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'] = tmpDir;
  });

  afterEach(() => {
    if (savedEnv === undefined) {
      delete process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'];
    } else {
      process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'] = savedEnv;
    }
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('throws LoginRequiredError when interactive login is disabled and no tokens exist', async () => {
    const strategy = createAuthStrategy(makeConfig(), logger, {
      allowInteractiveLogin: false,
    });

    await assert.rejects(
      () => strategy.getAccessToken(),
      (err: unknown) => {
        assert.ok(err instanceof LoginRequiredError);
        assert.equal(
          err.message,
          'No stored credentials found. Please log in first: salesforce-mcp-lib login --instance-url https://test.salesforce.com --client-id test-client-id'
        );
        return true;
      }
    );
  });

  it('uses the injected login handler when interactive login is enabled', async () => {
    let invoked = false;
    const fakeResponse: OAuthTokenResponse = {
      access_token: 'access-token-1234567890',
      refresh_token: 'refresh-token-1234567890',
      instance_url: 'https://test.salesforce.com',
      token_type: 'Bearer',
      id: 'https://login.salesforce.com/id/00Dxx/005xx',
      issued_at: '1700000000000',
    };

    const strategy: AuthStrategy = createAuthStrategy(makeConfig(), logger, {
      allowInteractiveLogin: true,
      loginHandler: async () => {
        invoked = true;
        return fakeResponse;
      },
    });

    const token = await strategy.getAccessToken();

    assert.equal(token, fakeResponse.access_token);
    assert.equal(invoked, true);
  });

  it('uses client credentials mode when clientSecret is configured even if stored tokens exist', () => {
    saveTokens(
      'https://test.salesforce.com',
      'test-client-id',
      makeTokenData(),
    );

    const strategy = createAuthStrategy(
      makeConfig({ clientSecret: 'test-client-secret' }),
      logger,
    );

    assert.ok(strategy instanceof ClientCredentialsStrategy);
    assert.equal(strategy.mode, 'client_credentials');
  });
});

describe('PerUserAuthStrategy single flight (H2)', () => {
  let tmpDir: string;
  let savedEnv: string | undefined;
  let server: http.Server;
  let baseUrl: string;
  let handler: (form: URLSearchParams, res: http.ServerResponse) => void;
  let hits: number;

  before(async () => {
    server = http.createServer((req, res) => {
      const chunks: Buffer[] = [];
      req.on('data', (c: Buffer) => chunks.push(c));
      req.on('end', () => {
        hits++;
        handler(new URLSearchParams(Buffer.concat(chunks).toString('utf8')), res);
      });
    });
    await new Promise<void>((r) => server.listen(0, '127.0.0.1', r));
    baseUrl = `http://127.0.0.1:${(server.address() as { port: number }).port}`;
  });
  after(async () => {
    await new Promise<void>((r) => server.close(() => r()));
  });

  beforeEach(() => {
    hits = 0;
    savedEnv = process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'];
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sfmcp-flight-'));
    process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'] = tmpDir;
  });
  afterEach(() => {
    if (savedEnv === undefined) delete process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'];
    else process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'] = savedEnv;
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  const tokens = (instanceUrl: string, overrides?: Partial<PerUserTokenData>): PerUserTokenData =>
    makeTokenData({ instanceUrl, accessToken: 'A1', refreshToken: 'R1', ...overrides });

  const issue = (res: http.ServerResponse, access: string, refresh: string): void => {
    setTimeout(() => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ access_token: access, refresh_token: refresh, instance_url: baseUrl, token_type: 'Bearer', id: 'id', issued_at: '5' }));
    }, 30);
  };

  function newStrategy(options: ConstructorParameters<typeof PerUserAuthStrategy>[2] = { allowInteractiveLogin: false }) {
    const config = makeConfig({ instanceUrl: baseUrl });
    saveTokens(baseUrl, config.clientId, tokens(baseUrl));
    return new PerUserAuthStrategy(config, logger, options);
  }

  it('coalesces initial acquisition: four callers, one refresh redemption', async () => {
    handler = (_form, res) => issue(res, 'A2', 'R2');
    const strategy = newStrategy();
    strategy.invalidateToken();

    const got = await Promise.all([1, 2, 3, 4].map(() => strategy.getAccessToken()));

    assert.deepEqual(got, ['A2', 'A2', 'A2', 'A2']);
    assert.equal(hits, 1);
  });

  it('shares one redemption across getAccessToken and reauthenticate', async () => {
    handler = (_form, res) => issue(res, 'A2', 'R2');
    const strategy = newStrategy();
    strategy.invalidateToken();

    const [token, reauth1, reauth2] = await Promise.all([
      strategy.getAccessToken(),
      strategy.reauthenticate('A1'),
      strategy.reauthenticate(),
    ]);

    assert.equal(token, 'A2');
    assert.equal(reauth1.access_token, 'A2');
    assert.equal(reauth2.access_token, 'A2');
    assert.equal(hits, 1);
  });

  it('reauthenticate for a failed token starts the refresh, so new callers wait instead of reusing it', async () => {
    handler = (_form, res) => issue(res, 'A2', 'R2');
    const strategy = newStrategy();

    const reauth = strategy.reauthenticate('A1');
    const concurrent = await strategy.getAccessToken(); // must not hand out the rejected A1

    assert.equal(concurrent, 'A2');
    assert.equal((await reauth).access_token, 'A2');
    assert.equal(hits, 1);
  });

  it('a stale failure for an already replaced token neither refreshes nor deletes tokens', async () => {
    handler = (_form, res) => issue(res, 'A2', 'R2');
    const strategy = newStrategy();
    await strategy.reauthenticate('A1');

    const late = await strategy.reauthenticate('A1');

    assert.equal(late.access_token, 'A2');
    assert.equal(hits, 1);
    const stored = loadTokens(baseUrl, 'test-client-id');
    assert.ok(stored.status === 'loaded' && stored.data.refreshToken === 'R2');
  });

  it('an invalid_grant is handled once for all waiters and clears the stored tokens once', async () => {
    handler = (_form, res) => {
      setTimeout(() => {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end('{"error":"invalid_grant","error_description":"expired"}');
      }, 30);
    };
    const strategy = newStrategy();
    strategy.invalidateToken();

    const results = await Promise.allSettled([1, 2, 3].map(() => strategy.getAccessToken()));

    for (const r of results) {
      assert.ok(r.status === 'rejected' && r.reason instanceof LoginRequiredError);
    }
    assert.equal(hits, 1);
    assert.equal(loadTokens(baseUrl, 'test-client-id').status, 'missing');
  });

  it('reauthenticate reports SessionExpiredError when the refresh token is dead and login is off', async () => {
    handler = (_form, res) => {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end('{"error":"invalid_grant"}');
    };
    const strategy = newStrategy();

    await assert.rejects(() => strategy.reauthenticate('A1'), SessionExpiredError);
  });

  it('a failed flight does not poison the next attempt', async () => {
    let first = true;
    handler = (_form, res) => {
      if (first) {
        first = false;
        res.writeHead(500);
        res.end('boom');
        return;
      }
      issue(res, 'A2', 'R2');
    };
    const strategy = newStrategy();
    strategy.invalidateToken();

    await assert.rejects(() => strategy.getAccessToken());
    assert.equal(await strategy.getAccessToken(), 'A2');
    assert.equal(hits, 2);
  });

  it('coalesces an interactive login', async () => {
    let logins = 0;
    const config = makeConfig({ instanceUrl: baseUrl });
    const strategy = new PerUserAuthStrategy(config, logger, {
      allowInteractiveLogin: true,
      loginHandler: async () => {
        logins++;
        await new Promise((r) => setTimeout(r, 30));
        return {
          access_token: 'L1', refresh_token: 'LR1', instance_url: baseUrl, token_type: 'Bearer', id: 'id', issued_at: '1',
        };
      },
    });

    const got = await Promise.all([1, 2, 3].map(() => strategy.getAccessToken()));

    assert.deepEqual(got, ['L1', 'L1', 'L1']);
    assert.equal(logins, 1);
  });
});
