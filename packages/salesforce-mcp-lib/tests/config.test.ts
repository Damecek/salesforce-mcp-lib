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
    // clientSecret is no longer required (per-user auth feature 003-per-user-auth)
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

describe('parseConfig — proxy bounds and target safety', () => {
  const ENV_KEYS = [...SF_ENV_KEYS, 'SF_REQUEST_TIMEOUT_MS', 'SF_MAX_CONCURRENCY'];
  let savedArgv: string[];
  let savedEnv: Record<string, string | undefined>;

  beforeEach(() => {
    savedArgv = process.argv;
    savedEnv = Object.fromEntries(ENV_KEYS.map((k) => [k, process.env[k]]));
    for (const k of ENV_KEYS) delete process.env[k];
  });

  afterEach(() => {
    process.argv = savedArgv;
    for (const k of ENV_KEYS) {
      if (savedEnv[k] === undefined) delete process.env[k];
      else process.env[k] = savedEnv[k];
    }
  });

  /** Run parseConfig with extra argv; returns config plus recorded exit codes and stderr. */
  function run(t: TestContext, extra: string[], argv: string[] = VALID_ARGV) {
    const exit = t.mock.method(process, 'exit', () => {});
    const err = t.mock.method(process.stderr, 'write', () => true);
    process.argv = [...argv, ...extra];
    const config = parseConfig();
    return {
      config,
      exits: exit.mock.calls.map((c) => c.arguments[0]),
      stderr: stderrOutput(err.mock),
    };
  }

  it('defaults to 120000 ms and 4 concurrent requests', (t: TestContext) => {
    const { config, exits } = run(t, []);
    assert.equal(config.requestTimeoutMs, 120000);
    assert.equal(config.maxConcurrency, 4);
    assert.deepEqual(exits, []);
  });

  it('reads the flags and the env vars, flags winning', (t: TestContext) => {
    process.env.SF_REQUEST_TIMEOUT_MS = '5000';
    process.env.SF_MAX_CONCURRENCY = '7';
    const env = run(t, []);
    assert.equal(env.config.requestTimeoutMs, 5000);
    assert.equal(env.config.maxConcurrency, 7);

    const flags = run(t, ['--request-timeout-ms', '1000', '--max-concurrency', '25']);
    assert.equal(flags.config.requestTimeoutMs, 1000);
    assert.equal(flags.config.maxConcurrency, 25);
  });

  for (const [flag, value] of [
    ['--request-timeout-ms', '999'],
    ['--request-timeout-ms', '600001'],
    ['--request-timeout-ms', '1e4'],
    ['--request-timeout-ms', 'abc'],
    ['--request-timeout-ms', '-5'],
    ['--max-concurrency', '0'],
    ['--max-concurrency', '26'],
    ['--max-concurrency', '2.5'],
    ['--max-concurrency', '3x'],
  ] as const) {
    it(`rejects ${flag} ${value}`, (t: TestContext) => {
      const { exits, stderr } = run(t, [flag, value]);
      assert.deepEqual(exits, [1]);
      assert.ok(stderr.includes(flag));
    });
  }

  it('rejects an invalid SF_MAX_CONCURRENCY env value', (t: TestContext) => {
    process.env.SF_MAX_CONCURRENCY = '99';
    assert.deepEqual(run(t, []).exits, [1]);
  });

  it('lists the new flags in the usage text', (t: TestContext) => {
    const { stderr } = run(t, ['--max-concurrency']);
    assert.ok(stderr.includes('--request-timeout-ms') && stderr.includes('SF_MAX_CONCURRENCY'));
  });

  it('rejects credentials in the instance URL without echoing them', (t: TestContext) => {
    const argv = VALID_ARGV.map((a) => (a === 'https://test.salesforce.com' ? 'https://user:hunter2@test.salesforce.com' : a));
    const { exits, stderr } = run(t, [], argv);
    assert.deepEqual(exits, [1]);
    assert.ok(!stderr.includes('hunter2'));
  });

  it('rejects a non-https instance URL unless it is exact loopback (M6)', (t: TestContext) => {
    const withUrl = (url: string): string[] => VALID_ARGV.map((a) => (a === 'https://test.salesforce.com' ? url : a));
    for (const url of ['http://test.salesforce.com', 'http://localhost.evil.com', 'http://127.0.0.1.evil.com', 'http://192.0.2.1', 'ftp://test.salesforce.com']) {
      const { exits, stderr } = run(t, [], withUrl(url));
      assert.deepEqual(exits, [1], url);
      assert.match(stderr, /must use https/);
      assert.ok(!stderr.includes(url), 'the URL is not echoed');
    }
  });

  it('accepts https custom domains and loopback http for local mocks', (t: TestContext) => {
    const withUrl = (url: string): string[] => VALID_ARGV.map((a) => (a === 'https://test.salesforce.com' ? url : a));
    for (const url of ['https://acme.my.salesforce.com', 'https://login.custom-domain.example', 'http://localhost:8080', 'http://127.0.0.1:9', 'http://[::1]:9']) {
      const { config, exits } = run(t, [], withUrl(url));
      assert.deepEqual(exits, [], url);
      assert.equal(config.instanceUrl, url);
    }
  });

  it('does not echo an unparseable instance URL', (t: TestContext) => {
    const argv = VALID_ARGV.map((a) => (a === 'https://test.salesforce.com' ? 'https//user:hunter2@nope' : a));
    const { exits, stderr } = run(t, [], argv);
    assert.deepEqual(exits, [1]);
    assert.ok(!stderr.includes('hunter2'));
  });

  it('rejects an endpoint that is not a path', (t: TestContext) => {
    for (const endpoint of ['https://evil.example/x', '//evil.example/x', 'services/apexrest/mcp']) {
      const argv = VALID_ARGV.map((a) => (a === '/services/apexrest/mcp' ? endpoint : a));
      assert.deepEqual(run(t, [], argv).exits, [1], endpoint);
    }
  });
});
