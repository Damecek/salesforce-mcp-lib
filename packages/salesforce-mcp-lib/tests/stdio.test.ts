import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import process from 'node:process';
import { EventEmitter } from 'node:events';
import { PassThrough } from 'node:stream';
import { LineSplitter, MAX_LINE_BYTES, MAX_QUEUE, createLogger, startStdioListener } from '../src/stdio.js';
import type { BridgeOutcome } from '../src/mcpBridge.js';
import type { StdioOptions } from '../src/stdio.js';
import type { ForwardableMessage } from '../src/protocol.js';

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

// ---------------------------------------------------------------------------
// LineSplitter
// ---------------------------------------------------------------------------

const lines = (events: ReturnType<LineSplitter['push']>): string[] =>
  events.map((e) => (e.type === 'line' ? e.bytes.toString('utf8') : '<oversize>'));

describe('LineSplitter', () => {
  it('splits on newlines across chunks', () => {
    const sp = new LineSplitter();
    assert.deepEqual(lines(sp.push(Buffer.from('ab\ncd'))), ['ab']);
    assert.deepEqual(lines(sp.push(Buffer.from('ef\ng\n'))), ['cdef', 'g']);
  });

  it('keeps a multi-byte character split across chunks intact', () => {
    const sp = new LineSplitter();
    const bytes = Buffer.from('世界\n', 'utf8');
    assert.deepEqual(lines(sp.push(bytes.subarray(0, 2))), []);
    assert.deepEqual(lines(sp.push(bytes.subarray(2))), ['世界']);
  });

  it('counts bytes, not characters', () => {
    const sp = new LineSplitter(5);
    assert.deepEqual(lines(sp.push(Buffer.from('世界\n'))), ['<oversize>']); // 6 bytes
    assert.deepEqual(lines(sp.push(Buffer.from('abcde\n'))), ['abcde']); // exactly 5 is allowed
  });

  it('reports an oversize line once, discards through the newline, then recovers', () => {
    const sp = new LineSplitter(4);
    assert.deepEqual(lines(sp.push(Buffer.from('abcdefgh'))), ['<oversize>']);
    assert.deepEqual(lines(sp.push(Buffer.from('ijkl'))), []);
    assert.deepEqual(lines(sp.push(Buffer.from('mn\nok\n'))), ['ok']);
  });

  it('flushes an unterminated last line, but not a discarded one', () => {
    const sp = new LineSplitter(4);
    sp.push(Buffer.from('ab'));
    assert.deepEqual(lines(sp.end()), ['ab']);
    sp.push(Buffer.from('abcdefg'));
    assert.deepEqual(lines(sp.end()), []);
  });
});

// ---------------------------------------------------------------------------
// startStdioListener
// ---------------------------------------------------------------------------

const quiet = { debug() {}, info() {}, warn() {}, error() {} };
const REQ = (id: string | number, method = 'tools/list'): string => JSON.stringify({ jsonrpc: '2.0', id, method }) + '\n';
const CANCEL = (requestId: string | number): string =>
  JSON.stringify({ jsonrpc: '2.0', method: 'notifications/cancelled', params: { requestId } }) + '\n';
const result = (id: string | number): BridgeOutcome => ({ kind: 'write', line: JSON.stringify({ jsonrpc: '2.0', id, result: {} }) });
const tick = (): Promise<void> => new Promise((r) => setImmediate(r));

interface Call {
  message: ForwardableMessage;
  signal: AbortSignal;
  resolve: (o: BridgeOutcome) => void;
}

function harness(maxConcurrency = 4, extra: Partial<StdioOptions> = {}) {
  const input = new PassThrough();
  const out: string[] = [];
  const calls: Call[] = [];
  const done = startStdioListener({
    forward: (message, signal) =>
      new Promise<BridgeOutcome>((resolve) => {
        calls.push({ message, signal, resolve });
      }),
    logger: quiet,
    maxConcurrency,
    input,
    output: { write: (chunk: unknown) => (out.push(String(chunk)), true) },
    ...extra,
  });
  const written = (): Record<string, any>[] => out.map((l) => JSON.parse(l));
  return { input, out, calls, done, written };
}

describe('startStdioListener', () => {
  it('answers a parse error without id', async () => {
    const h = harness();
    h.input.write('{bad\n');
    await tick();
    assert.deepEqual(h.written(), [{ jsonrpc: '2.0', error: { code: -32700, message: 'Parse error' } }]);
    assert.equal(h.calls.length, 0);
  });

  it('answers invalid UTF-8 as a parse error', async () => {
    const h = harness();
    h.input.write(Buffer.from([0x7b, 0xff, 0xfe, 0x7d, 0x0a]));
    await tick();
    assert.equal(h.written()[0]!['error'].code, -32700);
  });

  it('rejects a batch with -32600', async () => {
    const h = harness();
    h.input.write('[{"jsonrpc":"2.0","id":1,"method":"x"}]\n');
    await tick();
    assert.deepEqual(h.written(), [{ jsonrpc: '2.0', error: { code: -32600, message: 'Batch requests are not supported' } }]);
  });

  it('rejects ids the endpoint would refuse, and drops client responses silently', async () => {
    const h = harness();
    h.input.write('{"jsonrpc":"2.0","id":null,"method":"x"}\n{"jsonrpc":"2.0","id":1.5,"method":"x"}\n{"jsonrpc":"2.0","id":1,"result":{}}\n');
    await tick();
    assert.equal(h.written().length, 2);
    assert.ok(h.written().every((m) => m['error'].code === -32600 && !('id' in m)));
    assert.equal(h.calls.length, 0);
  });

  it('answers an oversize line with -32600 and keeps serving the stream', async () => {
    const h = harness();
    h.input.write(Buffer.alloc(MAX_LINE_BYTES + 1, 0x61));
    h.input.write(Buffer.alloc(1024, 0x61));
    h.input.write('\n' + REQ(1));
    await tick();
    assert.equal(h.written().length, 1);
    assert.equal(h.written()[0]!['error'].code, -32600);
    assert.equal(h.calls.length, 1);
  });

  it('forwards a notification and writes nothing', async () => {
    const h = harness();
    h.input.write('{"jsonrpc":"2.0","method":"notifications/initialized"}\n');
    await tick();
    h.calls[0]!.resolve({ kind: 'silent' });
    await tick();
    assert.equal(h.calls.length, 1);
    assert.equal(h.out.length, 0);
  });

  it('writes a forwarded response as one line', async () => {
    const h = harness();
    h.input.write(REQ(1));
    await tick();
    h.calls[0]!.resolve(result(1));
    await tick();
    assert.deepEqual(h.out, ['{"jsonrpc":"2.0","id":1,"result":{}}\n']);
  });

  it('honours the concurrency limit', async () => {
    const h = harness(2);
    h.input.write(REQ(1) + REQ(2) + REQ(3));
    await tick();
    assert.equal(h.calls.length, 2);
    h.calls[0]!.resolve(result(1));
    await tick();
    assert.equal(h.calls.length, 3);
  });

  it('rejects a duplicate of an in-flight id and keeps the original', async () => {
    const h = harness();
    h.input.write(REQ(5) + REQ(5));
    await tick();
    assert.equal(h.calls.length, 1);
    // No id: an echoed id could resolve the original, still running request with this error.
    assert.deepEqual(h.written(), [{ jsonrpc: '2.0', error: { code: -32600, message: 'Duplicate request id' } }]);
    h.calls[0]!.resolve(result(5));
    await tick();
    assert.equal(h.out.length, 2);
  });

  it('detects duplicates of a queued id', async () => {
    const h = harness(1);
    h.input.write(REQ(1) + REQ(2) + REQ(2));
    await tick();
    assert.equal(h.calls.length, 1);
    assert.equal(h.written()[0]!['error'].message, 'Duplicate request id');
  });

  it('treats "1" and 1 as different ids', async () => {
    const h = harness();
    h.input.write(REQ(1) + REQ('1'));
    await tick();
    assert.equal(h.calls.length, 2);
    assert.equal(h.out.length, 0);
  });

  it('allows an id again once its request has finished', async () => {
    const h = harness();
    h.input.write(REQ(1));
    await tick();
    h.calls[0]!.resolve(result(1));
    await tick();
    h.input.write(REQ(1));
    await tick();
    assert.equal(h.calls.length, 2);
  });

  it('cancels an in-flight request: aborts the signal and suppresses the response', async () => {
    const h = harness();
    h.input.write(REQ(1));
    await tick();
    h.input.write(CANCEL(1));
    await tick();
    assert.equal(h.calls[0]!.signal.aborted, true);
    h.calls[0]!.resolve(result(1)); // even a late response is dropped
    await tick();
    assert.equal(h.out.length, 0);
    assert.equal(h.calls.length, 1, 'the cancellation itself is never forwarded');
  });

  it('cancels a queued request before it is ever forwarded', async () => {
    const h = harness(1);
    h.input.write(REQ(1) + REQ(2));
    await tick();
    h.input.write(CANCEL(2));
    await tick();
    h.calls[0]!.resolve(result(1));
    await tick();
    assert.equal(h.calls.length, 1);
    assert.equal(h.out.length, 1);
  });

  it('cancel matches the id type and ignores unknown ids', async () => {
    const h = harness();
    h.input.write(REQ(1) + CANCEL('1') + CANCEL(99));
    await tick();
    assert.equal(h.calls[0]!.signal.aborted, false);
  });

  it('frees a cancelled id for immediate reuse', async () => {
    const h = harness();
    h.input.write(REQ(1) + CANCEL(1) + REQ(1));
    await tick();
    assert.equal(h.calls.length, 2);
    h.calls[0]!.resolve(result(1));
    await tick();
    assert.equal(h.out.length, 0, 'the old exchange must not release the new id');
    h.input.write(REQ(1));
    await tick();
    assert.equal(h.written()[0]!['error'].message, 'Duplicate request id');
  });

  it('answers with a local error when the queue is full', async () => {
    const h = harness(1);
    h.input.write(REQ(0));
    for (let i = 1; i <= MAX_QUEUE; i++) h.input.write(REQ(i));
    h.input.write(REQ(MAX_QUEUE + 1));
    await tick();
    assert.equal(h.written().length, 1);
    assert.equal(h.written()[0]!['id'], MAX_QUEUE + 1);
    assert.equal(h.written()[0]!['error'].data.source, 'salesforce-mcp-lib-proxy');
  });

  it('turns a rejected forward into a local error for requests', async () => {
    const input = new PassThrough();
    const out: string[] = [];
    void startStdioListener({
      forward: () => Promise.reject(new Error('boom')),
      logger: quiet,
      input,
      output: { write: (c: unknown) => (out.push(String(c)), true) },
    });
    input.write(REQ(8));
    await tick();
    await tick();
    assert.equal(JSON.parse(out[0]!).id, 8);
  });

  it('drains queued and in-flight work after stdin ends, then resolves', async () => {
    const h = harness(1);
    let finished = false;
    void h.done.then(() => (finished = true));
    h.input.write(REQ(1) + REQ(2));
    h.input.end();
    await tick();
    assert.equal(finished, false);
    h.calls[0]!.resolve(result(1));
    await tick();
    assert.equal(finished, false);
    h.calls[1]!.resolve(result(2));
    await h.done;
    assert.equal(h.out.length, 2);
  });

  it('processes a final line without a trailing newline', async () => {
    const h = harness();
    h.input.write(REQ(1).trim());
    h.input.end();
    await tick();
    assert.equal(h.calls.length, 1);
    h.calls[0]!.resolve(result(1));
    await h.done;
  });

  it('resolves immediately on an empty stream', async () => {
    const h = harness();
    h.input.end();
    await h.done;
  });
});

// ---------------------------------------------------------------------------
// Memory budget (H1)
// ---------------------------------------------------------------------------

/** A request padded to `size` bytes (newline included). */
const BIG = (id: number, size: number): string => {
  const base = JSON.stringify({ jsonrpc: '2.0', id, method: 'tools/call', params: { pad: '' } });
  return base.replace('"pad":""', `"pad":"${'x'.repeat(size - base.length - 1)}"`) + '\n';
};

describe('startStdioListener byte budget', () => {
  it('queues no message tree: a forwarded request carries only routing metadata and raw', async () => {
    const h = harness();
    h.input.write(BIG(1, 5000));
    await tick();
    assert.deepEqual(Object.keys(h.calls[0]!.message).sort(), ['headers', 'id', 'kind', 'method', 'raw']);
  });

  it('answers with a local error once queued and in-flight bytes exceed the budget', async () => {
    const h = harness(1, { maxQueuedBytes: 1000 });
    h.input.write(BIG(1, 400) + BIG(2, 400) + BIG(3, 400));
    await tick();
    assert.equal(h.calls.length, 1);
    assert.equal(h.written().length, 1);
    assert.equal(h.written()[0]!['id'], 3);
    assert.match(h.written()[0]!['error'].message, /queued request bytes/);
  });

  it('drops a notification over budget with a warning and no output', async () => {
    const warnings: string[] = [];
    const h = harness(1, { maxQueuedBytes: 500, logger: { ...quiet, warn: (m: string) => void warnings.push(m) } });
    h.input.write(BIG(1, 400));
    h.input.write(JSON.stringify({ jsonrpc: '2.0', method: 'notifications/x', params: { pad: 'y'.repeat(300) } }) + '\n');
    await tick();
    assert.equal(h.out.length, 0);
    assert.ok(warnings.some((w) => /Dropped notification/.test(w)));
  });

  it('releases the bytes when a request completes', async () => {
    const h = harness(1, { maxQueuedBytes: 1000 });
    h.input.write(BIG(1, 600));
    await tick();
    h.input.write(BIG(2, 600)); // would exceed while 1 is in flight
    await tick();
    assert.match(h.written()[0]!['error'].message, /queued request bytes/);
    h.calls[0]!.resolve(result(1));
    await tick();
    h.input.write(BIG(3, 600));
    await tick();
    assert.equal(h.calls.length, 2);
    assert.equal(h.calls[1]!.message.kind === 'request' && h.calls[1]!.message.id, 3);
  });

  it('releases the bytes of a cancelled queued request at once, and exactly once', async () => {
    const h = harness(1, { maxQueuedBytes: 1000 });
    h.input.write(BIG(1, 400) + BIG(2, 400));
    await tick();
    h.input.write(CANCEL(2) + CANCEL(2));
    await tick();
    h.input.write(BIG(3, 400)); // fits again: 400 in flight + 400
    h.input.write(BIG(4, 400)); // 1200 > 1000: a double release would let this in
    await tick();
    assert.equal(h.written().length, 1);
    assert.equal(h.written()[0]!['id'], 4);
  });

  it('releases the bytes of a cancelled in-flight request when its exchange ends', async () => {
    const h = harness(1, { maxQueuedBytes: 1000 });
    h.input.write(BIG(1, 600));
    await tick();
    h.input.write(CANCEL(1));
    await tick();
    h.calls[0]!.resolve({ kind: 'silent' });
    await tick();
    h.input.write(BIG(2, 900));
    await tick();
    assert.equal(h.out.length, 0);
    assert.equal(h.calls.length, 2);
  });

  it('releases the bytes of a rejected forward', async () => {
    const input = new PassThrough();
    const out: string[] = [];
    let n = 0;
    void startStdioListener({
      forward: () => (n++ === 0 ? Promise.reject(new Error('boom')) : new Promise(() => {})),
      logger: quiet,
      maxConcurrency: 1,
      maxQueuedBytes: 1000,
      input,
      output: { write: (c: unknown) => (out.push(String(c)), true) },
    });
    input.write(BIG(1, 900));
    await tick();
    await tick();
    input.write(BIG(2, 900));
    await tick();
    assert.equal(n, 2);
    assert.equal(out.length, 1); // only the local error for request 1
  });

  it('does not parse lines for debug logging: classification is the only parse', async (t) => {
    const messages: string[] = [];
    const h = harness(4, { logger: { ...quiet, debug: (m: string) => void messages.push(m) } });
    const parse = t.mock.method(JSON, 'parse');
    h.input.write(BIG(1, 20_000));
    await tick();
    h.calls[0]!.resolve({ kind: 'write', line: JSON.stringify({ jsonrpc: '2.0', id: 1, result: { pad: 'z'.repeat(20_000) } }) });
    await tick();
    const calls = parse.mock.callCount();
    parse.mock.restore();
    assert.equal(calls, 1);
    assert.ok(messages.some((m) => m.includes('"tools/call"') && m.includes('id:1')));
    assert.ok(messages.every((m) => !m.includes('xxxx') && !m.includes('zzzz')));
  });
});

// ---------------------------------------------------------------------------
// Output backpressure, EPIPE and closed output (M3)
// ---------------------------------------------------------------------------

/** A stand-in for a Writable whose buffer is full until `release()`. */
class SlowOutput extends EventEmitter {
  readonly lines: string[] = [];
  full = true;
  write(chunk: string, cb?: (err?: Error | null) => void): boolean {
    this.lines.push(chunk);
    cb?.();
    return !this.full;
  }
  release(): void {
    this.full = false;
    this.emit('drain');
  }
}

describe('startStdioListener output backpressure', () => {
  it('stops pumping and pauses input while the output is full, then resumes on drain', async () => {
    const out = new SlowOutput();
    const h = harness(1, { output: out });
    h.input.write(REQ(1) + REQ(2) + REQ(3));
    await tick();
    assert.equal(h.calls.length, 1);

    h.calls[0]!.resolve(result(1)); // this write returns false
    await tick();
    assert.equal(out.lines.length, 1);
    assert.equal(h.calls.length, 1, 'no new forward while blocked');
    assert.equal(h.input.isPaused(), true);

    h.input.write(REQ(4));
    await tick();
    assert.equal(h.calls.length, 1, 'input is not handled while blocked');

    out.release();
    await tick();
    assert.equal(h.calls.length, 2, 'queue resumes after drain');
    assert.equal(h.input.isPaused(), false);
  });

  it('holds the rest of a chunk instead of writing an unbounded run of errors', async () => {
    const out = new SlowOutput();
    const h = harness(4, { output: out });
    h.input.write('x\n'.repeat(50));
    await tick();
    assert.equal(out.lines.length, 1);
    out.release();
    await tick();
    assert.equal(out.lines.length, 50);
  });

  it('bounds writes while blocked to the requests already in flight', async () => {
    const out = new SlowOutput();
    const h = harness(2, { output: out });
    h.input.write(REQ(1) + REQ(2) + REQ(3) + REQ(4));
    await tick();
    h.calls[0]!.resolve(result(1));
    h.calls[1]!.resolve(result(2)); // already active, may still answer
    await tick();
    assert.equal(out.lines.length, 2);
    assert.equal(h.calls.length, 2, 'requests 3 and 4 wait');
  });

  it('settles after drain when stdin ended while blocked', async () => {
    const out = new SlowOutput();
    const h = harness(1, { output: out });
    h.input.write(REQ(1) + REQ(2));
    h.input.end();
    await tick();
    h.calls[0]!.resolve(result(1));
    await tick();
    out.release();
    await tick();
    h.calls[1]!.resolve(result(2));
    await h.done;
    assert.equal(out.lines.length, 2);
  });
});

describe('startStdioListener closed output', () => {
  it('aborts in-flight work, drops the queue, ignores later input and settles on an EPIPE error', async () => {
    const out = new SlowOutput();
    out.full = false;
    const h = harness(1, { output: out });
    h.input.write(REQ(1) + REQ(2));
    await tick();
    assert.equal(h.calls.length, 1);

    out.emit('error', Object.assign(new Error('write EPIPE'), { code: 'EPIPE' }));
    await h.done;
    assert.equal(h.calls[0]!.signal.aborted, true);

    h.calls[0]!.resolve(result(1)); // late result is suppressed
    h.input.write(REQ(3));
    await tick();
    assert.equal(out.lines.length, 0);
    assert.equal(h.calls.length, 1, 'queued request 2 and later request 3 never start');
  });

  it('settles when the output closes', async () => {
    const out = new SlowOutput();
    const h = harness(1, { output: out });
    h.input.write(REQ(1));
    await tick();
    out.emit('close');
    await h.done;
    assert.equal(h.calls[0]!.signal.aborted, true);
  });

  it('treats a failed write callback as a closed output', async () => {
    const out = new SlowOutput();
    out.write = (chunk: string, cb?: (err?: Error | null) => void): boolean => {
      out.lines.push(chunk);
      cb?.(new Error('write EPIPE'));
      return true;
    };
    const h = harness(1, { output: out });
    h.input.write('x\n' + REQ(1));
    await h.done;
    assert.equal(out.lines.length, 1, 'no write after the failure');
    assert.equal(h.calls.length, 0);
  });

  it('treats a throwing write as a closed output instead of crashing', async () => {
    const out = new SlowOutput();
    out.write = (): boolean => {
      throw new Error('ERR_STREAM_DESTROYED');
    };
    const h = harness(1, { output: out });
    h.input.write('x\n');
    await h.done;
  });

  it('a second error after shutdown does not throw', async () => {
    const out = new SlowOutput();
    const h = harness(1, { output: out });
    h.input.write(REQ(1));
    await tick();
    out.emit('error', new Error('EPIPE'));
    out.emit('error', new Error('EPIPE'));
    out.emit('close');
    await h.done;
  });
});
