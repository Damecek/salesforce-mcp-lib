import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import process from 'node:process';

// redactSecrets is exported from the CLI entry point which calls main() on
// import.  The module's top-level main().catch() eventually calls
// process.exit(1) and startStdioListener keeps the event loop alive.
//
// Strategy: set dummy env vars so parseConfig() passes, then mock
// process.exit to silently exit with code 0 (success) instead.  The test
// runner spawns a dedicated child process per file, so this is safe.

let redactSecrets: (text: string, secrets: string[]) => string;

// Capture the real exit before anything runs.
const realExit = process.exit.bind(process);

before(async () => {
  process.env['SF_INSTANCE_URL'] = 'https://test.salesforce.com';
  process.env['SF_CLIENT_ID'] = 'dummy-client-id';
  process.env['SF_CLIENT_SECRET'] = 'dummy-client-secret';
  process.env['SF_ENDPOINT'] = '/services/apexrest/mcp';

  // Redirect any process.exit(N) call to exit(0) so the test runner sees
  // a clean exit.  This must stay in place for the life of the subprocess
  // because main()'s auth failure + catch handler calls exit asynchronously.
  process.exit = ((_code?: number) => {
    realExit(0);
  }) as never;

  const mod = await import('../src/index.js');
  redactSecrets = mod.redactSecrets;
});

describe('redactSecrets', () => {
  it('replaces a single secret with "****"', () => {
    const result = redactSecrets('token is abc123', ['abc123']);
    assert.equal(result, 'token is ****');
  });

  it('replaces multiple occurrences of the same secret', () => {
    const result = redactSecrets('key=SECRET&verify=SECRET', ['SECRET']);
    assert.equal(result, 'key=****&verify=****');
  });

  it('replaces multiple different secrets', () => {
    const result = redactSecrets(
      'id=client1 secret=s3cret token=tok99',
      ['s3cret', 'tok99'],
    );
    assert.equal(result, 'id=client1 secret=**** token=****');
  });

  it('returns text unchanged when no secrets match', () => {
    const result = redactSecrets('nothing sensitive here', ['xyz']);
    assert.equal(result, 'nothing sensitive here');
  });

  it('skips empty-string secrets', () => {
    // An empty string secret should NOT cause every position to be replaced.
    const result = redactSecrets('hello world', ['']);
    assert.equal(result, 'hello world');
  });
});
