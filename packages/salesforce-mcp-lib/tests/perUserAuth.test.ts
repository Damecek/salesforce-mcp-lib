import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

import { parseHeadlessCallbackInput } from '../src/perUserAuth.js';

const CALLBACK_URL = 'http://localhost:13338/oauth/callback';
const EXPECTED_STATE = 'expected-state-123';

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
