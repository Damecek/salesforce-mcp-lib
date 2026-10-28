/**
 * Stdio transport — newline-delimited JSON-RPC over stdin/stdout.
 * T038 — levelled stderr logger.
 * v2 — byte-bounded line splitter, bounded queue and concurrency, local
 * cancellation, drain on stdin end (spec C3 7.1 and 7.4).
 */

import process from 'node:process';
import type { Readable } from 'node:stream';
import { classifyLine, localError, protocolError } from './protocol.js';
import type { Classified, ForwardableMessage, RequestId } from './protocol.js';
import type { BridgeOutcome } from './mcpBridge.js';

// ---------------------------------------------------------------------------
// Logger
// ---------------------------------------------------------------------------

/** Supported log levels, ordered by severity. */
const LOG_LEVELS = ['debug', 'info', 'warn', 'error'] as const;
type LogLevel = (typeof LOG_LEVELS)[number];

/** Stderr logger with level filtering. */
export interface Logger {
  debug(message: string): void;
  info(message: string): void;
  warn(message: string): void;
  error(message: string): void;
}

function levelIndex(level: string): number {
  const idx = LOG_LEVELS.indexOf(level as LogLevel);
  return idx === -1 ? 1 : idx; // default to 'info' for unrecognised values
}

/**
 * Create a levelled logger that writes exclusively to stderr.
 *
 * @param level Minimum severity to emit (debug | info | warn | error).
 */
export function createLogger(level: string): Logger {
  const threshold = levelIndex(level);

  function write(severity: LogLevel, message: string): void {
    if (levelIndex(severity) >= threshold) {
      const ts = new Date().toISOString();
      process.stderr.write(`[${ts}] [${severity.toUpperCase()}] ${message}\n`);
    }
  }

  return {
    debug: (msg: string) => write('debug', msg),
    info: (msg: string) => write('info', msg),
    warn: (msg: string) => write('warn', msg),
    error: (msg: string) => write('error', msg),
  };
}

// ---------------------------------------------------------------------------
// Line splitter
// ---------------------------------------------------------------------------

/** Longest accepted inbound line, in bytes (6 MiB). */
export const MAX_LINE_BYTES = 6 * 1024 * 1024;
/** Requests and notifications waiting for a free HTTP slot. */
export const MAX_QUEUE = 64;
/** Raw bytes of all queued and in-flight messages together (64 MiB). */
export const MAX_QUEUED_BYTES = 64 * 1024 * 1024;

export type SplitEvent = { type: 'line'; bytes: Buffer } | { type: 'oversize' };

/**
 * Splits a byte stream on 0x0A. Works on bytes so multi-byte UTF-8
 * characters spanning chunks stay intact and the limit is in bytes. An
 * oversize line emits one event and its remainder is discarded through the
 * next newline.
 */
export class LineSplitter {
  private parts: Buffer[] = [];
  private size = 0;
  private discarding = false;

  constructor(private readonly maxBytes: number = MAX_LINE_BYTES) {}

  push(chunk: Buffer): SplitEvent[] {
    const events: SplitEvent[] = [];
    let start = 0;
    while (start < chunk.length) {
      const nl = chunk.indexOf(0x0a, start);
      const end = nl === -1 ? chunk.length : nl;
      if (!this.discarding) {
        if (this.size + (end - start) > this.maxBytes) {
          this.discarding = true;
          this.parts = [];
          this.size = 0;
          events.push({ type: 'oversize' });
        } else {
          this.parts.push(chunk.subarray(start, end));
          this.size += end - start;
        }
      }
      if (nl === -1) break;
      if (!this.discarding) events.push({ type: 'line', bytes: Buffer.concat(this.parts) });
      this.parts = [];
      this.size = 0;
      this.discarding = false;
      start = nl + 1;
    }
    return events;
  }

  /** Flush an unterminated final line at end of input. */
  end(): SplitEvent[] {
    const events: SplitEvent[] = [];
    if (!this.discarding && this.size > 0) events.push({ type: 'line', bytes: Buffer.concat(this.parts) });
    this.parts = [];
    this.size = 0;
    this.discarding = false;
    return events;
  }
}

// ---------------------------------------------------------------------------
// Stdio listener
// ---------------------------------------------------------------------------

/** What the listener needs from stdout; a real `Writable` satisfies it. */
export interface OutputStream {
  write(chunk: string, callback?: (error?: Error | null) => void): boolean | void;
  on?(event: 'drain' | 'error' | 'close', listener: (...args: any[]) => void): unknown;
  off?(event: 'drain' | 'error' | 'close', listener: (...args: any[]) => void): unknown;
}

export interface StdioOptions {
  forward: (message: ForwardableMessage, signal: AbortSignal) => Promise<BridgeOutcome>;
  logger: Logger;
  /** Concurrent forwards. Defaults to 4. */
  maxConcurrency?: number;
  /** Cap on raw bytes held by queued and in-flight messages. Defaults to 64 MiB. */
  maxQueuedBytes?: number;
  input?: Readable;
  output?: OutputStream;
}

interface Pending {
  message: ForwardableMessage;
  controller: AbortController;
  cancelled: boolean;
  /** Raw bytes counted against the budget until released. */
  bytes: number;
  released: boolean;
}

const utf8 = new TextDecoder('utf-8', { fatal: true });

/**
 * Read newline-delimited JSON-RPC from `input`, forward requests and
 * notifications, and write each response (plus newline) to `output`.
 *
 * Backpressure: once `output.write` returns false the listener starts no new
 * forwards and stops handling input (the stream is paused) until `drain`.
 * Only forwards already running can still write, so the output backlog is
 * bounded by `maxConcurrency` responses. If `output` errors or closes, every
 * queued and in-flight message is dropped or aborted and the promise resolves.
 *
 * Returns a promise that resolves once input has ended and every queued and
 * in-flight message has finished (each is bounded by the bridge timeout), or
 * once the output is gone.
 */
export function startStdioListener(options: StdioOptions): Promise<void> {
  const { forward, logger } = options;
  const maxConcurrency = options.maxConcurrency ?? 4;
  const maxQueuedBytes = options.maxQueuedBytes ?? MAX_QUEUED_BYTES;
  const input = options.input ?? process.stdin;
  const output: OutputStream = options.output ?? process.stdout;
  const splitter = new LineSplitter();

  /** Queued and in-flight requests by `JSON.stringify(id)`, so "1" and 1 differ. */
  const byId = new Map<string, Pending>();
  const queue: Pending[] = [];
  /** Split lines not yet handled because the output is blocked. */
  const events: SplitEvent[] = [];
  const running = new Set<Pending>();
  let queuedBytes = 0;
  let active = 0;
  let ended = false;
  let blocked = false;
  let closed = false;
  let resolveDone: () => void = () => {};
  const done = new Promise<void>((resolve) => {
    resolveDone = resolve;
  });

  const idKey = (id: RequestId): string => JSON.stringify(id);

  /** Give back an item's bytes exactly once. */
  function release(item: Pending): void {
    if (item.released) return;
    item.released = true;
    queuedBytes -= item.bytes;
  }

  function settleIfDone(): void {
    if (ended && queue.length === 0 && active === 0 && events.length === 0) resolveDone();
  }

  function onDrain(): void {
    if (closed || !blocked) return;
    blocked = false;
    drainEvents();
    pump();
    if (!blocked && !ended) input.resume();
  }

  function shutdownOutput(reason: string): void {
    if (closed) return;
    closed = true;
    logger.error(`stdout ${reason} — aborting ${running.size} in-flight and dropping ${queue.length} queued messages`);
    input.off('data', onData);
    input.pause();
    for (const item of queue.splice(0)) release(item);
    events.length = 0;
    for (const item of running) {
      item.cancelled = true;
      item.controller.abort();
    }
    byId.clear();
    resolveDone();
  }

  const write = (line: string, summary: string): void => {
    if (closed) return;
    logger.debug(`stdout << ${summary}`);
    let accepted: boolean | void;
    try {
      accepted = output.write(line + '\n', (err) => {
        if (err) shutdownOutput(`write failed (${err.message})`);
      });
    } catch (err: unknown) {
      shutdownOutput(`write failed (${err instanceof Error ? err.message : String(err)})`);
      return;
    }
    // Without event support the caller cannot signal drain, so never block on it.
    if (accepted === false && !blocked && output.on) {
      blocked = true;
      input.pause();
    }
  };

  function pump(): void {
    while (!blocked && !closed && active < maxConcurrency && queue.length > 0) {
      const item = queue.shift()!;
      active++;
      running.add(item);
      void run(item);
    }
    settleIfDone();
  }

  async function run(item: Pending): Promise<void> {
    const { message } = item;
    try {
      const outcome = await forward(message, item.controller.signal);
      if (outcome.kind === 'write' && !item.cancelled) {
        write(outcome.line, `${message.kind === 'request' ? `response id:${idKey(message.id)}` : 'line'}, ${outcome.line.length} chars`);
      }
    } catch (err: unknown) {
      logger.error(`Unhandled error processing message: ${err instanceof Error ? err.message : String(err)}`);
      if (message.kind === 'request' && !item.cancelled) {
        write(localError(message.id, 'Internal proxy error', null), `error id:${idKey(message.id)}`);
      }
    } finally {
      // A cancelled id is released at once and may already belong to a newer request.
      if (message.kind === 'request' && byId.get(idKey(message.id)) === item) {
        byId.delete(idKey(message.id));
      }
      running.delete(item);
      release(item);
      active--;
      pump();
    }
  }

  function enqueue(message: ForwardableMessage, bytes: number): void {
    const fail = (reason: string): void => {
      if (message.kind === 'request') {
        write(localError(message.id, reason, null), `error id:${idKey(message.id)}`);
      } else {
        logger.warn(`Dropped notification: ${reason}`);
      }
    };
    if (queue.length >= MAX_QUEUE) return fail('Too many queued requests');
    if (queuedBytes + bytes > maxQueuedBytes) return fail('Too many queued request bytes');
    const item: Pending = { message, controller: new AbortController(), cancelled: false, bytes, released: false };
    queuedBytes += bytes;
    if (message.kind === 'request') byId.set(idKey(message.id), item);
    queue.push(item);
    pump();
  }

  function cancel(requestId: RequestId): void {
    const item = byId.get(idKey(requestId));
    if (!item) return;
    item.cancelled = true;
    item.controller.abort();
    byId.delete(idKey(requestId));
    const queued = queue.indexOf(item);
    if (queued !== -1) {
      queue.splice(queued, 1);
      release(item); // never started, so nothing else will release it
    }
    // A running item releases in run() once the aborted exchange unwinds.
  }

  function handleLine(bytes: Buffer): void {
    let line: string;
    try {
      line = utf8.decode(bytes).trim();
    } catch {
      write(protocolError(-32700, 'Parse error'), 'parse error');
      return;
    }
    if (line.length === 0) return;

    const msg = classifyLine(line);
    // Log only JSON-RPC metadata (id + method), never bodies, and never re-parse the line.
    logger.debug(`stdin >> ${describe(msg, bytes.length)}`);
    switch (msg.kind) {
      case 'parse-error':
        write(protocolError(-32700, 'Parse error'), 'parse error');
        return;
      case 'batch':
        write(protocolError(-32600, 'Batch requests are not supported'), 'invalid request');
        return;
      case 'invalid':
        write(protocolError(-32600, msg.reason, msg.id), 'invalid request');
        return;
      case 'drop':
        logger.debug(`Dropped inbound message: ${msg.reason}`);
        return;
      case 'cancel':
        cancel(msg.requestId);
        return;
      case 'request':
        if (byId.has(idKey(msg.id))) {
          // No id: echoing it could resolve the original, still running request with this error.
          write(protocolError(-32600, 'Duplicate request id'), 'duplicate request id');
          return;
        }
        enqueue(msg, bytes.length);
        return;
      case 'notification':
        enqueue(msg, bytes.length);
        return;
    }
  }

  /** Handle split lines in order until the output blocks. */
  function drainEvents(): void {
    while (!blocked && !closed && events.length > 0) {
      const event = events.shift()!;
      if (event.type === 'oversize') {
        write(protocolError(-32600, 'Message exceeds the 6 MiB line limit'), 'oversize line');
      } else {
        handleLine(event.bytes);
      }
    }
    settleIfDone();
  }

  function onData(chunk: Buffer | string): void {
    for (const event of splitter.push(typeof chunk === 'string' ? Buffer.from(chunk, 'utf8') : chunk)) {
      events.push(event);
    }
    drainEvents();
  }

  output.on?.('drain', onDrain);
  output.on?.('error', (err: Error) => shutdownOutput(`error (${err.message})`));
  output.on?.('close', () => shutdownOutput('closed'));

  input.on('data', onData);
  input.on('end', () => {
    for (const event of splitter.end()) events.push(event);
    drainEvents();
    logger.info('stdin closed — draining in-flight requests');
    ended = true;
    settleIfDone();
  });
  input.on('error', (err: Error) => {
    logger.error(`stdin error: ${err.message}`);
    ended = true;
    settleIfDone();
  });

  return done;
}

/** Log summary for a classified line: id and method only, bounded. */
function describe(msg: Classified, bytes: number): string {
  switch (msg.kind) {
    case 'request':
      return `{id:${JSON.stringify(msg.id)}, method:${JSON.stringify(msg.method.slice(0, 64))}, ${bytes} bytes}`;
    case 'notification':
      return `{method:${JSON.stringify(msg.method.slice(0, 64))}, ${bytes} bytes}`;
    default:
      return `(${msg.kind}, ${bytes} bytes)`;
  }
}
