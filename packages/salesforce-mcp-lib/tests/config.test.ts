import { describe, it, beforeEach, afterEach, type TestContext } from 'node:test';
import assert from 'node:assert/strict';
import process from 'node:process';
import { parseConfig } from '../src/config.js';

/** Env vars that parseConfig reads — saved/restored around every test. */
const SF_ENV_KEYS = [
  'SF_INSTANCE_URL',
  'SF_CLIENT_ID',
  'SF_CLIENT_SECRET',
  'SF_ENDPOINT',
  'SF_LOG_LEVEL',
] as const;

/** Complete valid env var set for happy-path tests. */
const VALID_ENV = {
  SF_INSTANCE_URL: 'https://test.salesforce.com',
  SF_CLIENT_ID: 'test-client-id',
  SF_CLIENT_SECRET: 'test-client-secret',
  SF_ENDPOINT: '/services/apexrest/mcp',
} as const;

/** Complete valid CLI argv for happy-path tests. */
const VALID_ARGV = [
  'node',
  'index.js',
  '--instance-url',
  'https://test.salesforce.com',
  '--client-id',
  'test-client-id',
  '--client-secret',
  'test-client-secret',
  '--endpoint',
  '/services/apexrest/mcp',
];

/** Helper: collect all stderr.write calls into a single string. */
function stderrOutput(mock: { calls: { arguments: unknown[] }[] }): string {
  return mock.calls.map((c) => String(c.arguments[0])).join('');
}

describe('parseConfig', () => {
  let savedArgv: string[];
  let savedEnv: Record<string, string | undefined>;

  beforeEach(() => {
    savedArgv = process.argv;
    savedEnv = {};
    for (const key of SF_ENV_KEYS) {
      savedEnv[key] = process.env[key];
    }
  });

  afterEach(() => {
    process.argv = savedArgv;
    for (const key of SF_ENV_KEYS) {
      if (savedEnv[key] === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = savedEnv[key];
      }
    }
  });

  /** Set all SF_ env vars from VALID_ENV and clear SF_LOG_LEVEL. */
  function setValidEnv(): void {
    for (const [k, v] of Object.entries(VALID_ENV)) {
      process.env[k] = v;
    }
    delete process.env.SF_LOG_LEVEL;
  }

  /** Clear all SF_ env vars so only CLI flags are used. */
  function clearEnv(): void {
    for (const key of SF_ENV_KEYS) {
      delete process.env[key];
    }
  }

  // ── Happy-path tests ─────────────────────────────────────────────

  it('parses all required from env vars', (t: TestContext) => {
    setValidEnv();
    process.argv = ['node', 'index.js'];

    const config = parseConfig();

    assert.equal(config.instanceUrl, 'https://test.salesforce.com');
    assert.equal(config.clientId, 'test-client-id');
    assert.equal(config.clientSecret, 'test-client-secret');
    assert.equal(config.endpoint, '/services/apexrest/mcp');
  });

  it('defaults logLevel to info when SF_LOG_LEVEL not set', (t: TestContext) => {
    setValidEnv();
    process.argv = ['node', 'index.js'];

    const config = parseConfig();

    assert.equal(config.logLevel, 'info');
  });

  it('reads SF_LOG_LEVEL optional env var', (t: TestContext) => {
    setValidEnv();
    process.env.SF_LOG_LEVEL = 'debug';
    process.argv = ['node', 'index.js'];

    const config = parseConfig();

    assert.equal(config.logLevel, 'debug');
  });

  it('ignores empty env vars (SF_INSTANCE_URL="" treated as missing)', (t: TestContext) => {
    t.mock.method(process, 'exit', () => {});
    t.mock.method(process.stderr, 'write', () => true);

    setValidEnv();
    process.env.SF_INSTANCE_URL = '';
    process.argv = ['node', 'index.js'];

    parseConfig();

    const exitMock = process.exit as unknown as { mock: { calls: { arguments: unknown[] }[] } };
    assert.equal(exitMock.mock.calls.length, 1);
    assert.deepEqual(exitMock.mock.calls[0].arguments, [1]);
  });

  it('parses all required from CLI flags', (t: TestContext) => {
    clearEnv();
    process.argv = [...VALID_ARGV];

    const config = parseConfig();

    assert.equal(config.instanceUrl, 'https://test.salesforce.com');
    assert.equal(config.clientId, 'test-client-id');
    assert.equal(config.clientSecret, 'test-client-secret');
    assert.equal(config.endpoint, '/services/apexrest/mcp');
  });

  it('CLI flag overrides env var (precedence)', (t: TestContext) => {
    setValidEnv();
    process.argv = [
      'node',
      'index.js',
      '--instance-url',
      'https://override.salesforce.com',
    ];

    const config = parseConfig();

    assert.equal(config.instanceUrl, 'https://override.salesforce.com');
    // Other values still come from env
    assert.equal(config.clientId, 'test-client-id');
  });

  it('env var used when CLI flag absent (fallback)', (t: TestContext) => {
    setValidEnv();
    // Only pass --instance-url via CLI; the rest come from env
    process.argv = [
      'node',
      'index.js',
      '--instance-url',
      'https://cli.salesforce.com',
    ];

    const config = parseConfig();

    assert.equal(config.instanceUrl, 'https://cli.salesforce.com');
    assert.equal(config.clientId, 'test-client-id');
    assert.equal(config.clientSecret, 'test-client-secret');
    assert.equal(config.endpoint, '/services/apexrest/mcp');
  });

  // ── Error tests ──────────────────────────────────────────────────

  it('exit(1) on missing required key with stderr message listing missing keys', (t: TestContext) => {
    t.mock.method(process, 'exit', () => {});
    const writeMock = t.mock.method(process.stderr, 'write', () => true);

    clearEnv();
    // Provide all except endpoint
    process.argv = [
      'node',
      'index.js',
      '--instance-url',
      'https://test.salesforce.com',
      '--client-id',
      'test-client-id',
      '--client-secret',
      'test-client-secret',
    ];

    parseConfig();

    const exitMock = process.exit as unknown as { mock: { calls: { arguments: unknown[] }[] } };
    assert.equal(exitMock.mock.calls.length, 1);
    assert.deepEqual(exitMock.mock.calls[0].arguments, [1]);

    const output = stderrOutput(writeMock.mock);
    assert.ok(output.includes('endpoint'), 'stderr should mention missing key "endpoint"');
  });

  it('exit(1) on multiple missing keys - stderr contains all names', (t: TestContext) => {
    t.mock.method(process, 'exit', () => {});
    const writeMock = t.mock.method(process.stderr, 'write', () => true);

    clearEnv();
    process.argv = ['node', 'index.js'];

    parseConfig();

    const exitMock = process.exit as unknown as { mock: { calls: { arguments: unknown[] }[] } };
    assert.equal(exitMock.mock.calls.length, 1);
    assert.deepEqual(exitMock.mock.calls[0].arguments, [1]);

    const output = stderrOutput(writeMock.mock);
    assert.ok(output.includes('instanceUrl'), 'stderr should mention instanceUrl');
    assert.ok(output.includes('clientId'), 'stderr should mention clientId');
    assert.ok(output.includes('clientSecret'), 'stderr should mention clientSecret');
    assert.ok(output.includes('endpoint'), 'stderr should mention endpoint');
  });

  it('exit(1) on flag without value (--instance-url at end of argv)', (t: TestContext) => {
    t.mock.method(process, 'exit', () => {});
    const writeMock = t.mock.method(process.stderr, 'write', () => true);

    clearEnv();
    process.argv = ['node', 'index.js', '--instance-url'];

    parseConfig();

    const exitMock = process.exit as unknown as { mock: { calls: { arguments: unknown[] }[] } };
    assert.ok(exitMock.mock.calls.length >= 1, 'process.exit should have been called');
    assert.deepEqual(exitMock.mock.calls[0].arguments, [1]);

    const output = stderrOutput(writeMock.mock);
    assert.ok(
      output.includes('--instance-url') && output.includes('requires a value'),
      'stderr should mention that --instance-url requires a value'
    );
  });

  it('exit(1) on flag value that is another flag (--instance-url --client-id)', (t: TestContext) => {
    t.mock.method(process, 'exit', () => {});
    const writeMock = t.mock.method(process.stderr, 'write', () => true);

    clearEnv();
    process.argv = ['node', 'index.js', '--instance-url', '--client-id'];

    parseConfig();

    const exitMock = process.exit as unknown as { mock: { calls: { arguments: unknown[] }[] } };
    assert.ok(exitMock.mock.calls.length >= 1, 'process.exit should have been called');
    assert.deepEqual(exitMock.mock.calls[0].arguments, [1]);

    const output = stderrOutput(writeMock.mock);
    assert.ok(
      output.includes('--instance-url') && output.includes('requires a value'),
      'stderr should mention that --instance-url requires a value'
    );
  });

  it('unknown flags are ignored (--unknown value does not break parsing)', (t: TestContext) => {
    clearEnv();
    process.argv = [
      'node',
      'index.js',
      '--unknown',
      'some-value',
      '--instance-url',
      'https://test.salesforce.com',
      '--client-id',
      'test-client-id',
      '--client-secret',
      'test-client-secret',
      '--endpoint',
      '/services/apexrest/mcp',
    ];

    const config = parseConfig();

    assert.equal(config.instanceUrl, 'https://test.salesforce.com');
    assert.equal(config.clientId, 'test-client-id');
    assert.equal(config.clientSecret, 'test-client-secret');
    assert.equal(config.endpoint, '/services/apexrest/mcp');
  });
});
