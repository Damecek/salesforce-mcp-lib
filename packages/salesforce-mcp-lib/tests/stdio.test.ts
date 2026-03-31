import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import process from 'node:process';
import { createLogger } from '../src/stdio.js';

describe('createLogger', () => {
  describe('debug level: emits all 4 levels', () => {
    it('calls stderr.write 4 times for debug, info, warn, error', (t) => {
      const mock = t.mock.method(process.stderr, 'write', () => true);
      const logger = createLogger('debug');

      logger.debug('d');
      logger.info('i');
      logger.warn('w');
      logger.error('e');

      assert.strictEqual(mock.mock.calls.length, 4);
    });
  });

  describe('info level: suppresses debug', () => {
    it('does not write debug, writes info/warn/error', (t) => {
      const mock = t.mock.method(process.stderr, 'write', () => true);
      const logger = createLogger('info');

      logger.debug('should be suppressed');
      assert.strictEqual(mock.mock.calls.length, 0);

      logger.info('i');
      assert.strictEqual(mock.mock.calls.length, 1);

      logger.warn('w');
      assert.strictEqual(mock.mock.calls.length, 2);

      logger.error('e');
      assert.strictEqual(mock.mock.calls.length, 3);
    });
  });

  describe('warn level: suppresses debug + info', () => {
    it('only warn and error produce output', (t) => {
      const mock = t.mock.method(process.stderr, 'write', () => true);
      const logger = createLogger('warn');

      logger.debug('suppressed');
      logger.info('suppressed');
      assert.strictEqual(mock.mock.calls.length, 0);

      logger.warn('w');
      assert.strictEqual(mock.mock.calls.length, 1);

      logger.error('e');
      assert.strictEqual(mock.mock.calls.length, 2);
    });
  });

  describe('error level: only emits error', () => {
    it('suppresses debug, info, warn and only writes error', (t) => {
      const mock = t.mock.method(process.stderr, 'write', () => true);
      const logger = createLogger('error');

      logger.debug('suppressed');
      logger.info('suppressed');
      logger.warn('suppressed');
      assert.strictEqual(mock.mock.calls.length, 0);

      logger.error('e');
      assert.strictEqual(mock.mock.calls.length, 1);
    });
  });

  describe('output format', () => {
    it('matches ISO timestamp, level label, and message with trailing newline', (t) => {
      const mock = t.mock.method(process.stderr, 'write', () => true);
      const logger = createLogger('info');

      logger.info('hello world');

      assert.strictEqual(mock.mock.calls.length, 1);
      const output = mock.mock.calls[0].arguments[0] as string;
      assert.match(
        output,
        /^\[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z\] \[INFO\] hello world\n$/
      );
    });
  });

  describe('uppercase level labels', () => {
    it('uses DEBUG, INFO, WARN, ERROR in output', (t) => {
      const mock = t.mock.method(process.stderr, 'write', () => true);
      const logger = createLogger('debug');

      logger.debug('msg');
      logger.info('msg');
      logger.warn('msg');
      logger.error('msg');

      const labels = mock.mock.calls.map(
        (call) => ((call.arguments[0] as string).match(/\[([A-Z]+)\]/) ?? [])[1]
      );
      assert.deepStrictEqual(labels, ['DEBUG', 'INFO', 'WARN', 'ERROR']);
    });
  });

  describe('unknown level defaults to info', () => {
    it('suppresses debug but emits info for an unrecognised level string', (t) => {
      const mock = t.mock.method(process.stderr, 'write', () => true);
      const logger = createLogger('bogus');

      logger.debug('suppressed');
      assert.strictEqual(mock.mock.calls.length, 0);

      logger.info('visible');
      assert.strictEqual(mock.mock.calls.length, 1);
    });
  });

  describe('returns object with 4 log methods', () => {
    it('debug, info, warn, error are all functions', () => {
      const logger = createLogger('info');

      assert.strictEqual(typeof logger.debug, 'function');
      assert.strictEqual(typeof logger.info, 'function');
      assert.strictEqual(typeof logger.warn, 'function');
      assert.strictEqual(typeof logger.error, 'function');
    });
  });
});
