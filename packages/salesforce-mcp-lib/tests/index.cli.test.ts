import { afterEach, beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const packageDir = fileURLToPath(new URL('..', import.meta.url));
const entrypoint = fileURLToPath(new URL('../src/index.ts', import.meta.url));

describe('CLI server mode auth startup', () => {
  let tmpDir: string;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sfmcp-cli-'));
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('fails fast with exit code 2 when per-user auth has no stored login', () => {
    const env = { ...process.env };
    delete env['SF_INSTANCE_URL'];
    delete env['SF_CLIENT_ID'];
    delete env['SF_CLIENT_SECRET'];
    delete env['SF_ENDPOINT'];

    const result = spawnSync(
      process.execPath,
      [
        '--import',
        'tsx',
        entrypoint,
        '--instance-url',
        'https://test.salesforce.com',
        '--client-id',
        'test-client-id',
        '--endpoint',
        '/services/apexrest/mcp',
      ],
      {
        cwd: packageDir,
        env: {
          ...env,
          SALESFORCE_MCP_LIB_STORAGE_DIR: tmpDir,
        },
        encoding: 'utf8',
        timeout: 5000,
      }
    );

    assert.equal(result.signal, null);
    assert.equal(result.status, 2);
    assert.match(
      result.stderr,
      /No stored credentials found\. Please log in first: salesforce-mcp-lib login --instance-url https:\/\/test\.salesforce\.com --client-id test-client-id/
    );
    assert.doesNotMatch(
      result.stderr,
      /Please open this URL in a browser to authorize:/
    );
  });
});
