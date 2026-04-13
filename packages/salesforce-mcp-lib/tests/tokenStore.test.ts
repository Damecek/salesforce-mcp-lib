/**
 * Tests for tokenStore.ts — file-based token persistence with AES-256-GCM encryption.
 *
 * Isolation strategy: each describe block sets process.env.SALESFORCE_MCP_LIB_STORAGE_DIR
 * to a unique temporary directory created in beforeEach and removed in afterEach.
 * This redirects all getStorageDir() and getKeyFilePath() calls to the temp dir without
 * touching the real ~/.salesforce-mcp-lib directory.
 */

import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

import {
  deriveStorageKey,
  getStorageDir,
  getKeyFilePath,
  saveTokens,
  loadTokens,
  deleteTokens,
} from '../src/tokenStore.js';
import type { PerUserTokenData } from '../src/types.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Minimal valid PerUserTokenData fixture. */
function makeTokenData(overrides?: Partial<PerUserTokenData>): PerUserTokenData {
  return {
    accessToken: 'acc_test_token',
    refreshToken: 'ref_test_token',
    instanceUrl: 'https://test.my.salesforce.com',
    tokenType: 'Bearer',
    issuedAt: 1700000000000,
    identityUrl: 'https://login.salesforce.com/id/00Dxx/005xx',
    ...overrides,
  };
}

const INSTANCE_URL = 'https://test.my.salesforce.com';
const CLIENT_ID = 'test-client-id';

// ---------------------------------------------------------------------------
// deriveStorageKey
// ---------------------------------------------------------------------------

describe('deriveStorageKey', () => {
  it('returns a 64-char lowercase hex string (SHA-256)', () => {
    const key = deriveStorageKey(INSTANCE_URL, CLIENT_ID);
    assert.match(key, /^[0-9a-f]{64}$/);
  });

  it('is deterministic for the same inputs', () => {
    const a = deriveStorageKey(INSTANCE_URL, CLIENT_ID);
    const b = deriveStorageKey(INSTANCE_URL, CLIENT_ID);
    assert.equal(a, b);
  });

  it('treats a trailing slash as the same org URL', () => {
    const a = deriveStorageKey('https://org.my.salesforce.com', CLIENT_ID);
    const b = deriveStorageKey('https://org.my.salesforce.com/', CLIENT_ID);
    assert.equal(a, b);
  });

  it('treats an explicit default https port as the same org URL', () => {
    const a = deriveStorageKey('https://org.my.salesforce.com', CLIENT_ID);
    const b = deriveStorageKey('https://org.my.salesforce.com:443', CLIENT_ID);
    assert.equal(a, b);
  });

  it('differs when instanceUrl differs', () => {
    const a = deriveStorageKey('https://org-a.my.salesforce.com', CLIENT_ID);
    const b = deriveStorageKey('https://org-b.my.salesforce.com', CLIENT_ID);
    assert.notEqual(a, b);
  });

  it('differs when clientId differs', () => {
    const a = deriveStorageKey(INSTANCE_URL, 'client-a');
    const b = deriveStorageKey(INSTANCE_URL, 'client-b');
    assert.notEqual(a, b);
  });
});

// ---------------------------------------------------------------------------
// getStorageDir / getKeyFilePath — env var override
// ---------------------------------------------------------------------------

describe('getStorageDir + getKeyFilePath env override', () => {
  let savedEnv: string | undefined;
  let tmpDir: string;

  beforeEach(() => {
    savedEnv = process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'];
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sfmcp-test-'));
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

  it('getStorageDir() returns <tmpDir>/tokens', () => {
    assert.equal(getStorageDir(), path.join(tmpDir, 'tokens'));
  });

  it('getKeyFilePath() returns <tmpDir>/.key', () => {
    assert.equal(getKeyFilePath(), path.join(tmpDir, '.key'));
  });
});

// ---------------------------------------------------------------------------
// saveTokens + loadTokens round-trip
// ---------------------------------------------------------------------------

describe('saveTokens + loadTokens round-trip', () => {
  let savedEnv: string | undefined;
  let tmpDir: string;

  beforeEach(() => {
    savedEnv = process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'];
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sfmcp-test-'));
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

  it('round-trips all PerUserTokenData fields', () => {
    const data = makeTokenData();
    saveTokens(INSTANCE_URL, CLIENT_ID, data);
    const result = loadTokens(INSTANCE_URL, CLIENT_ID);
    assert.equal(result.status, 'loaded');
    if (result.status !== 'loaded') return;
    assert.deepEqual(result.data, data);
  });

  it('creates the tokens directory', () => {
    saveTokens(INSTANCE_URL, CLIENT_ID, makeTokenData());
    assert.ok(fs.existsSync(getStorageDir()));
  });

  it('creates the key file on first save', () => {
    saveTokens(INSTANCE_URL, CLIENT_ID, makeTokenData());
    assert.ok(fs.existsSync(getKeyFilePath()));
  });

  it('token file is NOT readable as plain JSON with accessToken', () => {
    const data = makeTokenData();
    saveTokens(INSTANCE_URL, CLIENT_ID, data);
    const storageKey = deriveStorageKey(INSTANCE_URL, CLIENT_ID);
    const filePath = path.join(getStorageDir(), `${storageKey}.json`);
    const raw = JSON.parse(fs.readFileSync(filePath, 'utf-8')) as Record<string, unknown>;
    // Encrypted format must have v/iv/tag/ct — not accessToken
    assert.equal(raw['v'], 1);
    assert.ok(typeof raw['iv'] === 'string');
    assert.ok(typeof raw['tag'] === 'string');
    assert.ok(typeof raw['ct'] === 'string');
    assert.equal(raw['accessToken'], undefined);
    assert.equal(raw['refreshToken'], undefined);
  });

  it('token file has mode 0o600', () => {
    saveTokens(INSTANCE_URL, CLIENT_ID, makeTokenData());
    const storageKey = deriveStorageKey(INSTANCE_URL, CLIENT_ID);
    const filePath = path.join(getStorageDir(), `${storageKey}.json`);
    const mode = fs.statSync(filePath).mode & 0o777;
    assert.equal(mode, 0o600);
  });

  it('key file has mode 0o400', () => {
    saveTokens(INSTANCE_URL, CLIENT_ID, makeTokenData());
    const mode = fs.statSync(getKeyFilePath()).mode & 0o777;
    assert.equal(mode, 0o400);
  });

  it('no .tmp file remains after successful save', () => {
    saveTokens(INSTANCE_URL, CLIENT_ID, makeTokenData());
    const storageKey = deriveStorageKey(INSTANCE_URL, CLIENT_ID);
    const tmpPath = path.join(getStorageDir(), `${storageKey}.json.tmp`);
    assert.ok(!fs.existsSync(tmpPath));
  });

  it('overwrites existing tokens with new data', () => {
    saveTokens(INSTANCE_URL, CLIENT_ID, makeTokenData({ accessToken: 'old_acc' }));
    saveTokens(INSTANCE_URL, CLIENT_ID, makeTokenData({ accessToken: 'new_acc' }));
    const result = loadTokens(INSTANCE_URL, CLIENT_ID);
    assert.equal(result.status, 'loaded');
    if (result.status !== 'loaded') return;
    assert.equal(result.data.accessToken, 'new_acc');
  });

  it('stores tokens independently per instanceUrl', () => {
    const url1 = 'https://org1.my.salesforce.com';
    const url2 = 'https://org2.my.salesforce.com';
    saveTokens(url1, CLIENT_ID, makeTokenData({ accessToken: 'acc1', instanceUrl: url1 }));
    saveTokens(url2, CLIENT_ID, makeTokenData({ accessToken: 'acc2', instanceUrl: url2 }));

    const r1 = loadTokens(url1, CLIENT_ID);
    const r2 = loadTokens(url2, CLIENT_ID);
    assert.equal(r1.status, 'loaded');
    assert.equal(r2.status, 'loaded');
    if (r1.status !== 'loaded' || r2.status !== 'loaded') return;
    assert.equal(r1.data.accessToken, 'acc1');
    assert.equal(r2.data.accessToken, 'acc2');
  });

  it('loads tokens saved with a trailing slash via the canonical URL form', () => {
    const savedUrl = 'https://org.my.salesforce.com/';
    const loadedUrl = 'https://org.my.salesforce.com';
    const data = makeTokenData({ instanceUrl: savedUrl });

    saveTokens(savedUrl, CLIENT_ID, data);

    const result = loadTokens(loadedUrl, CLIENT_ID);
    assert.equal(result.status, 'loaded');
    if (result.status !== 'loaded') return;
    assert.deepEqual(result.data, data);
  });

  it('loads tokens saved with an explicit default port via the canonical URL form', () => {
    const savedUrl = 'https://org.my.salesforce.com:443';
    const loadedUrl = 'https://org.my.salesforce.com/';
    const data = makeTokenData({ instanceUrl: savedUrl });

    saveTokens(savedUrl, CLIENT_ID, data);

    const result = loadTokens(loadedUrl, CLIENT_ID);
    assert.equal(result.status, 'loaded');
    if (result.status !== 'loaded') return;
    assert.deepEqual(result.data, data);
  });
});

// ---------------------------------------------------------------------------
// loadTokens — status variants
// ---------------------------------------------------------------------------

describe('loadTokens — status: missing', () => {
  let savedEnv: string | undefined;
  let tmpDir: string;

  beforeEach(() => {
    savedEnv = process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'];
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sfmcp-test-'));
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

  it('returns { status: missing } when no file exists', () => {
    const result = loadTokens(INSTANCE_URL, CLIENT_ID);
    assert.equal(result.status, 'missing');
  });
});

describe('loadTokens — status: corrupt', () => {
  let savedEnv: string | undefined;
  let tmpDir: string;

  beforeEach(() => {
    savedEnv = process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'];
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sfmcp-test-'));
    process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'] = tmpDir;
    fs.mkdirSync(getStorageDir(), { recursive: true });
  });

  afterEach(() => {
    if (savedEnv === undefined) {
      delete process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'];
    } else {
      process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'] = savedEnv;
    }
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  function writeTokenFile(content: string): void {
    const storageKey = deriveStorageKey(INSTANCE_URL, CLIENT_ID);
    const filePath = path.join(getStorageDir(), `${storageKey}.json`);
    fs.writeFileSync(filePath, content, { mode: 0o600 });
  }

  it('returns corrupt on invalid JSON', () => {
    writeTokenFile('not-json{{{');
    const result = loadTokens(INSTANCE_URL, CLIENT_ID);
    assert.equal(result.status, 'corrupt');
    if (result.status !== 'corrupt') return;
    assert.ok(result.reason.includes('JSON'));
  });

  it('returns corrupt on JSON missing required fields', () => {
    writeTokenFile(JSON.stringify({ accessToken: '', refreshToken: 'tok' }));
    const result = loadTokens(INSTANCE_URL, CLIENT_ID);
    assert.equal(result.status, 'corrupt');
  });

  it('returns corrupt on unrecognized JSON object', () => {
    writeTokenFile(JSON.stringify({ someOtherField: 'value' }));
    const result = loadTokens(INSTANCE_URL, CLIENT_ID);
    assert.equal(result.status, 'corrupt');
    if (result.status !== 'corrupt') return;
    assert.ok(result.reason.includes('Unrecognized'));
  });

  it('returns corrupt when ciphertext is tampered', () => {
    saveTokens(INSTANCE_URL, CLIENT_ID, makeTokenData());
    const storageKey = deriveStorageKey(INSTANCE_URL, CLIENT_ID);
    const filePath = path.join(getStorageDir(), `${storageKey}.json`);
    const envelope = JSON.parse(fs.readFileSync(filePath, 'utf-8')) as {
      v: number; iv: string; tag: string; ct: string;
    };
    // Flip the first two characters of ciphertext.
    const tamperedCt =
      (envelope.ct.charCodeAt(0) === 48 ? 'f' : '0') + envelope.ct.slice(1);
    envelope.ct = tamperedCt;
    fs.writeFileSync(filePath, JSON.stringify(envelope), { mode: 0o600 });

    const result = loadTokens(INSTANCE_URL, CLIENT_ID);
    assert.equal(result.status, 'corrupt');
    if (result.status !== 'corrupt') return;
    assert.ok(result.reason.includes('Decryption failed'));
  });

  it('returns corrupt when auth tag is tampered', () => {
    saveTokens(INSTANCE_URL, CLIENT_ID, makeTokenData());
    const storageKey = deriveStorageKey(INSTANCE_URL, CLIENT_ID);
    const filePath = path.join(getStorageDir(), `${storageKey}.json`);
    const envelope = JSON.parse(fs.readFileSync(filePath, 'utf-8')) as {
      v: number; iv: string; tag: string; ct: string;
    };
    // Replace tag with all-zero hex.
    envelope.tag = '0'.repeat(32);
    fs.writeFileSync(filePath, JSON.stringify(envelope), { mode: 0o600 });

    const result = loadTokens(INSTANCE_URL, CLIENT_ID);
    assert.equal(result.status, 'corrupt');
    if (result.status !== 'corrupt') return;
    assert.ok(result.reason.includes('Decryption failed'));
  });
});

describe('loadTokens — status: error (missing key file)', () => {
  let savedEnv: string | undefined;
  let tmpDir: string;

  beforeEach(() => {
    savedEnv = process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'];
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sfmcp-test-'));
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

  it('returns { status: error } when encrypted file exists but key file is missing', () => {
    // Save tokens (creates key + encrypted file).
    saveTokens(INSTANCE_URL, CLIENT_ID, makeTokenData());
    // Delete the key file.
    fs.unlinkSync(getKeyFilePath());

    const result = loadTokens(INSTANCE_URL, CLIENT_ID);
    assert.equal(result.status, 'error');
    if (result.status !== 'error') return;
    assert.ok(result.error.message.includes('missing'));
    assert.ok(result.error.message.includes('salesforce-mcp-lib login'));
  });
});

// ---------------------------------------------------------------------------
// loadTokens — legacy plaintext auto-migration
// ---------------------------------------------------------------------------

describe('loadTokens — legacy plaintext migration', () => {
  let savedEnv: string | undefined;
  let tmpDir: string;

  beforeEach(() => {
    savedEnv = process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'];
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sfmcp-test-'));
    process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'] = tmpDir;
    fs.mkdirSync(getStorageDir(), { recursive: true });
  });

  afterEach(() => {
    if (savedEnv === undefined) {
      delete process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'];
    } else {
      process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'] = savedEnv;
    }
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  function writeLegacyFile(data: PerUserTokenData): string {
    const storageKey = deriveStorageKey(INSTANCE_URL, CLIENT_ID);
    const filePath = path.join(getStorageDir(), `${storageKey}.json`);
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2), { mode: 0o600 });
    return filePath;
  }

  it('loads a legacy plaintext file successfully', () => {
    const data = makeTokenData();
    writeLegacyFile(data);
    const result = loadTokens(INSTANCE_URL, CLIENT_ID);
    assert.equal(result.status, 'loaded');
    if (result.status !== 'loaded') return;
    assert.equal(result.data.accessToken, data.accessToken);
    assert.equal(result.data.refreshToken, data.refreshToken);
  });

  it('auto-upgrades the plaintext file to encrypted format', () => {
    writeLegacyFile(makeTokenData());
    // First load triggers the upgrade.
    loadTokens(INSTANCE_URL, CLIENT_ID);

    // Now the file should be in encrypted format.
    const storageKey = deriveStorageKey(INSTANCE_URL, CLIENT_ID);
    const filePath = path.join(getStorageDir(), `${storageKey}.json`);
    const raw = JSON.parse(fs.readFileSync(filePath, 'utf-8')) as Record<string, unknown>;
    assert.equal(raw['v'], 1);
    assert.ok(typeof raw['ct'] === 'string');
    assert.equal(raw['accessToken'], undefined);
  });

  it('after upgrade, a second loadTokens still returns the same data', () => {
    const data = makeTokenData();
    writeLegacyFile(data);
    loadTokens(INSTANCE_URL, CLIENT_ID); // triggers upgrade
    const result = loadTokens(INSTANCE_URL, CLIENT_ID); // reads encrypted
    assert.equal(result.status, 'loaded');
    if (result.status !== 'loaded') return;
    assert.equal(result.data.accessToken, data.accessToken);
  });

  it('returns corrupt for a legacy file missing the refreshToken field', () => {
    const storageKey = deriveStorageKey(INSTANCE_URL, CLIENT_ID);
    const filePath = path.join(getStorageDir(), `${storageKey}.json`);
    fs.writeFileSync(
      filePath,
      JSON.stringify({ accessToken: 'tok', instanceUrl: INSTANCE_URL }),
      { mode: 0o600 }
    );
    // Missing refreshToken → isLegacyPlaintext is false (no refreshToken),
    // and it's not encrypted format → unrecognized format.
    const result = loadTokens(INSTANCE_URL, CLIENT_ID);
    assert.equal(result.status, 'corrupt');
  });
});

// ---------------------------------------------------------------------------
// deleteTokens
// ---------------------------------------------------------------------------

describe('deleteTokens', () => {
  let savedEnv: string | undefined;
  let tmpDir: string;

  beforeEach(() => {
    savedEnv = process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'];
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sfmcp-test-'));
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

  it('removes an existing token file', () => {
    saveTokens(INSTANCE_URL, CLIENT_ID, makeTokenData());
    deleteTokens(INSTANCE_URL, CLIENT_ID);

    const storageKey = deriveStorageKey(INSTANCE_URL, CLIENT_ID);
    const filePath = path.join(getStorageDir(), `${storageKey}.json`);
    assert.ok(!fs.existsSync(filePath));
  });

  it('subsequent loadTokens returns missing after delete', () => {
    saveTokens(INSTANCE_URL, CLIENT_ID, makeTokenData());
    deleteTokens(INSTANCE_URL, CLIENT_ID);
    const result = loadTokens(INSTANCE_URL, CLIENT_ID);
    assert.equal(result.status, 'missing');
  });

  it('is a no-op when the token file does not exist', () => {
    // Should not throw.
    assert.doesNotThrow(() => {
      deleteTokens(INSTANCE_URL, CLIENT_ID);
    });
  });

  it('does NOT delete the key file', () => {
    saveTokens(INSTANCE_URL, CLIENT_ID, makeTokenData());
    deleteTokens(INSTANCE_URL, CLIENT_ID);
    assert.ok(fs.existsSync(getKeyFilePath()));
  });

  it('does not affect tokens for a different org', () => {
    const otherUrl = 'https://other.my.salesforce.com';
    saveTokens(INSTANCE_URL, CLIENT_ID, makeTokenData());
    saveTokens(otherUrl, CLIENT_ID, makeTokenData({ instanceUrl: otherUrl }));

    deleteTokens(INSTANCE_URL, CLIENT_ID);

    const result = loadTokens(otherUrl, CLIENT_ID);
    assert.equal(result.status, 'loaded');
  });
});
