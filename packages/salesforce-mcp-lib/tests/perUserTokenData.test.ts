import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

import { SalesforceAuthError } from '../src/errors.js';
import { buildPerUserTokenData } from '../src/perUserTokenData.js';
import type { OAuthTokenResponse } from '../src/types.js';

function makeResponse(
  overrides?: Partial<OAuthTokenResponse>,
): OAuthTokenResponse {
  return {
    access_token: 'access-token-123',
    instance_url: 'https://test.salesforce.com',
    token_type: 'Bearer',
    id: 'https://login.salesforce.com/id/00Dxx/005xx',
    issued_at: '1700000000000',
    ...overrides,
  };
}

describe('buildPerUserTokenData', () => {
  it('throws when initial login omits refresh_token', () => {
    assert.throws(
      () => buildPerUserTokenData(makeResponse()),
      (err: unknown) => {
        assert.ok(err instanceof SalesforceAuthError);
        assert.match(
          err.message,
          /did not return a refresh token.*refresh_token scope.*offline access/i,
        );
        return true;
      },
    );
  });

  it('reuses the existing refresh token for refresh responses', () => {
    const result = buildPerUserTokenData(
      makeResponse({ access_token: 'fresh-access-token' }),
      'stored-refresh-token',
    );

    assert.equal(result.accessToken, 'fresh-access-token');
    assert.equal(result.refreshToken, 'stored-refresh-token');
  });

  it('uses refresh_token returned by initial login', () => {
    const result = buildPerUserTokenData(
      makeResponse({ refresh_token: 'new-refresh-token' }),
    );

    assert.equal(result.refreshToken, 'new-refresh-token');
    assert.equal(result.instanceUrl, 'https://test.salesforce.com');
  });
});
