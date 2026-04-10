import { afterEach, beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

import {
  createAuthStrategy,
  type AuthStrategy,
} from '../src/authStrategy.js';
import { LoginRequiredError } from '../src/errors.js';
import type { AuthConfig, OAuthTokenResponse } from '../src/types.js';

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
});
