import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import type { IncomingMessage, ServerResponse } from 'node:http';

import {
  parseHeadlessCallbackInput,
  refreshAccessToken,
} from '../src/perUserAuth.js';
import {
  InvalidCredentialsError,
  SessionExpiredError,
} from '../src/errors.js';

const CALLBACK_URL = 'http://localhost:13338/oauth/callback';
const EXPECTED_STATE = 'expected-state-123';

let serverHandler: (req: IncomingMessage, res: ServerResponse) => void;
let server: http.Server;
let baseUrl: string;

before(async () => {
  server = http.createServer((req, res) => serverHandler(req, res));
  await new Promise<void>((resolve) => server.listen(0, resolve));
  const addr = server.address() as { port: number };
  baseUrl = `http://localhost:${addr.port}`;
});

after(async () => {
  await new Promise<void>((resolve) => server.close(() => resolve()));
});

describe('parseHeadlessCallbackInput', () => {
  it('accepts a full callback URL with matching state', () => {
    const result = parseHeadlessCallbackInput(
      'http://localhost:13338/oauth/callback?code=auth-code-123&state=expected-state-123',
      CALLBACK_URL,
      EXPECTED_STATE
    );

    assert.deepEqual(result, {
      code: 'auth-code-123',
      state: EXPECTED_STATE,
    });
  });

  it('rejects a callback URL missing state', () => {
    assert.throws(
      () =>
        parseHeadlessCallbackInput(
          'http://localhost:13338/oauth/callback?code=auth-code-123',
          CALLBACK_URL,
          EXPECTED_STATE
        ),
      /Missing state in callback URL/
    );
  });

  it('rejects a callback URL with mismatched state', () => {
    assert.throws(
      () =>
        parseHeadlessCallbackInput(
          'http://localhost:13338/oauth/callback?code=auth-code-123&state=wrong-state',
          CALLBACK_URL,
          EXPECTED_STATE
        ),
      /OAuth state mismatch/
    );
  });

  it('rejects a raw authorization code', () => {
    assert.throws(
      () =>
        parseHeadlessCallbackInput(
          'auth-code-123',
          CALLBACK_URL,
          EXPECTED_STATE
        ),
      /Paste the full callback URL/
    );
  });

  it('rejects a callback URL with the wrong port', () => {
    assert.throws(
      () =>
        parseHeadlessCallbackInput(
          'http://localhost:13339/oauth/callback?code=auth-code-123&state=expected-state-123',
          CALLBACK_URL,
          EXPECTED_STATE
        ),
      /Invalid callback URL/
    );
  });
});

describe('refreshAccessToken', () => {
  it('maps invalid_grant to SessionExpiredError', async () => {
    serverHandler = (_req, res) => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(
        JSON.stringify({
          error: 'invalid_grant',
          error_description: 'expired refresh token',
        })
      );
    };

    await assert.rejects(
      () => refreshAccessToken(baseUrl, 'client-id', 'refresh-token'),
      (err: unknown) => {
        assert.ok(err instanceof SessionExpiredError);
        assert.match(err.message, /session has expired/i);
        return true;
      },
    );
  });

  it('preserves invalid_client as InvalidCredentialsError', async () => {
    serverHandler = (_req, res) => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(
        JSON.stringify({
          error: 'invalid_client',
          error_description: 'bad client configuration',
        })
      );
    };

    await assert.rejects(
      () => refreshAccessToken(baseUrl, 'client-id', 'refresh-token'),
      (err: unknown) => {
        assert.ok(err instanceof InvalidCredentialsError);
        assert.equal(err.oauthError, 'invalid_client');
        assert.match(err.message, /External Client App authentication failed/);
        return true;
      },
    );
  });
});
