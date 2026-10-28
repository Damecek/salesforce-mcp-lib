/**
 * Pure MCP wire helpers for the stdio proxy (spec C3, sections 7.1 to 7.3).
 * No I/O here: classification of inbound lines, outbound headers, remote
 * response interpretation and local error construction.
 */

export const MODERN_VERSION = '2026-07-28';
export const LEGACY_VERSION = '2025-11-25';
export const PROTOCOL_VERSION_META_KEY = 'io.modelcontextprotocol/protocolVersion';

export const PROXY_ERROR_SOURCE = 'salesforce-mcp-lib-proxy';

export type RequestId = string | number;

// ---------------------------------------------------------------------------
// Inbound classification (7.1)
// ---------------------------------------------------------------------------

/**
 * How the Mcp-* headers for one message are produced. Decided while the
 * message is classified, so nothing from `params` has to be retained.
 * `name` is the already-encoded `Mcp-Name` value.
 */
export type HeaderPlan =
  | { kind: 'modern'; version: string; name?: string }
  | { kind: 'legacy' }
  | { kind: 'invalid'; reason: string };

/** Longest method, protocol version or header-bound name kept, in chars. */
export const MAX_METHOD_CHARS = 256;
/** Longest raw `params.name` / `params.uri` that is mirrored into `Mcp-Name`. */
export const MAX_NAME_CHARS = 2048;

export interface RequestMessage {
  kind: 'request';
  id: RequestId;
  method: string;
  headers: HeaderPlan;
  /** The original line, forwarded byte for byte. Parsed params are not kept. */
  raw: string;
}

export interface NotificationMessage {
  kind: 'notification';
  method: string;
  headers: HeaderPlan;
  raw: string;
}

export type ForwardableMessage = RequestMessage | NotificationMessage;

export type Classified =
  | ForwardableMessage
  | { kind: 'cancel'; requestId: RequestId }
  | { kind: 'parse-error' }
  | { kind: 'batch' }
  | { kind: 'invalid'; id?: RequestId; reason: string }
  | { kind: 'drop'; reason: string };

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/** A request id the Apex endpoint accepts: a string or an integral number. */
export function isValidRequestId(id: unknown): id is RequestId {
  return typeof id === 'string' || (typeof id === 'number' && Number.isSafeInteger(id));
}

export function classifyLine(line: string): Classified {
  let parsed: unknown;
  try {
    parsed = JSON.parse(line);
  } catch {
    return { kind: 'parse-error' };
  }
  if (Array.isArray(parsed)) return { kind: 'batch' };
  if (!isRecord(parsed)) return { kind: 'invalid', reason: 'Invalid Request' };

  const validId = isValidRequestId(parsed['id']) ? parsed['id'] : undefined;

  if (!('method' in parsed)) {
    // A client response to a server request. We never send server requests.
    if (('result' in parsed || 'error' in parsed) && 'id' in parsed) {
      return { kind: 'drop', reason: 'client response' };
    }
    return { kind: 'invalid', id: validId, reason: 'Invalid Request' };
  }
  if (parsed['jsonrpc'] !== '2.0' || typeof parsed['method'] !== 'string') {
    return { kind: 'invalid', id: validId, reason: 'Invalid Request' };
  }
  const method = parsed['method'];
  if (method.length > MAX_METHOD_CHARS) {
    return { kind: 'invalid', id: validId, reason: 'Invalid Request' };
  }

  if (!('id' in parsed)) {
    if (method === 'notifications/cancelled') {
      const params = parsed['params'];
      const requestId = isRecord(params) ? params['requestId'] : undefined;
      return isValidRequestId(requestId)
        ? { kind: 'cancel', requestId }
        : { kind: 'drop', reason: 'cancellation without a valid requestId' };
    }
    return { kind: 'notification', method, headers: planHeaders(method, parsed['params']), raw: line };
  }
  if (validId === undefined) {
    return { kind: 'invalid', reason: 'Invalid request id' };
  }
  return { kind: 'request', id: validId, method, headers: planHeaders(method, parsed['params']), raw: line };
}

// ---------------------------------------------------------------------------
// Outbound headers (7.2)
// ---------------------------------------------------------------------------

const BASE64_SENTINEL = /^=\?base64\?[\s\S]*\?=$/;
const VISIBLE_ASCII = /^[\x21-\x7E]+$/;
const PLAIN_VALUE = /^[\x20-\x7E]*$/;

/** Encode an `Mcp-Name` value: plain when safe, `=?base64?...?=` otherwise. */
export function encodeHeaderValue(value: string): string {
  const plain =
    PLAIN_VALUE.test(value) && value === value.trim() && !BASE64_SENTINEL.test(value);
  return plain ? value : `=?base64?${Buffer.from(value, 'utf8').toString('base64')}?=`;
}

export type HeaderResult =
  | { ok: true; headers: Record<string, string> }
  | { ok: false; reason: string };

/** Method to the `params` key that `Mcp-Name` mirrors. */
const NAME_PARAM: Record<string, string> = {
  'tools/call': 'name',
  'prompts/get': 'name',
  'resources/read': 'uri',
};

const INVALID_VERSION: HeaderPlan = {
  kind: 'invalid',
  reason: 'Invalid MCP protocol version in _meta: expected visible ASCII text',
};

/**
 * Decide the header plan for one message. A `_meta` protocol-version key marks
 * a modern message; a malformed value is rejected, never treated as legacy.
 */
export function planHeaders(method: string, params: unknown): HeaderPlan {
  const p = isRecord(params) ? params : undefined;
  const meta = p && isRecord(p['_meta']) ? p['_meta'] : undefined;
  if (!meta || !(PROTOCOL_VERSION_META_KEY in meta)) return { kind: 'legacy' };

  const version = meta[PROTOCOL_VERSION_META_KEY];
  if (typeof version !== 'string' || version.length > MAX_METHOD_CHARS || !VISIBLE_ASCII.test(version)) {
    return INVALID_VERSION;
  }
  if (method.length > MAX_METHOD_CHARS || !VISIBLE_ASCII.test(method)) {
    return { kind: 'invalid', reason: 'Invalid method: expected visible ASCII text for the Mcp-Method header' };
  }
  const nameKey = NAME_PARAM[method];
  const name = nameKey && p ? p[nameKey] : undefined;
  if (typeof name !== 'string') return { kind: 'modern', version };
  if (name.length > MAX_NAME_CHARS) {
    return { kind: 'invalid', reason: 'Invalid request: the name or uri is too long for the Mcp-Name header' };
  }
  return { kind: 'modern', version, name: encodeHeaderValue(name) };
}

/** Protocol headers for a plan. `legacyVersion` is what a prior `initialize` negotiated, if any. */
export function headersFromPlan(
  plan: HeaderPlan,
  method: string,
  legacyVersion: string | null
): HeaderResult {
  if (plan.kind === 'invalid') return { ok: false, reason: plan.reason };
  if (plan.kind === 'modern') {
    const headers: Record<string, string> = {
      'MCP-Protocol-Version': plan.version,
      'Mcp-Method': method,
    };
    if (plan.name !== undefined) headers['Mcp-Name'] = plan.name;
    return { ok: true, headers };
  }
  if (method === 'initialize') return { ok: true, headers: {} };
  return { ok: true, headers: legacyVersion ? { 'MCP-Protocol-Version': legacyVersion } : {} };
}

/** Plan and build in one step, for callers that still hold the parsed params. */
export function buildHeaders(
  msg: { method: string; params?: unknown },
  legacyVersion: string | null
): HeaderResult {
  return headersFromPlan(planHeaders(msg.method, msg.params), msg.method, legacyVersion);
}

// ---------------------------------------------------------------------------
// Remote response handling (7.3)
// ---------------------------------------------------------------------------

export type RemoteOutcome =
  | { kind: 'write'; line: string; protocolVersion?: string }
  | { kind: 'silent'; warn?: string }
  | { kind: 'local'; reason: string; httpStatus: number | null };

function statusReason(status: number): string {
  if (status === 500) return 'The remote Apex endpoint returned an internal error';
  if (status === 401 || status === 403) {
    return 'Authorization error communicating with the remote endpoint';
  }
  return `The remote endpoint returned an unexpected status (HTTP ${status})`;
}

/**
 * Decide what to emit for a remote HTTP result. `requestId` is `undefined`
 * for a notification, which never produces output (errors become a warning).
 */
export function interpretRemote(
  status: number,
  body: string,
  requestId: RequestId | undefined
): RemoteOutcome {
  if (requestId === undefined) {
    return status >= 200 && status < 300
      ? { kind: 'silent' }
      : { kind: 'silent', warn: `notification POST returned HTTP ${status}` };
  }

  const text = body.trim();
  if (text.length === 0) {
    return {
      kind: 'local',
      reason:
        status === 202 || status === 204
          ? 'The remote endpoint acknowledged a request without a response'
          : 'The remote endpoint returned an empty response',
      httpStatus: status,
    };
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    return { kind: 'local', reason: statusReason(status), httpStatus: status };
  }
  if (!isRecord(parsed) || parsed['jsonrpc'] !== '2.0') {
    return { kind: 'local', reason: statusReason(status), httpStatus: status };
  }

  const hasResult = 'result' in parsed;
  const error = parsed['error'];
  const hasError = 'error' in parsed;
  const errorValid =
    isRecord(error) && Number.isInteger(error['code']) && typeof error['message'] === 'string';
  if (hasResult === hasError || (hasError && !errorValid)) {
    return { kind: 'local', reason: 'The remote endpoint returned a malformed JSON-RPC envelope', httpStatus: status };
  }

  const result = parsed['result'];
  const protocolVersion =
    isRecord(result) && typeof result['protocolVersion'] === 'string' ? result['protocolVersion'] : undefined;

  const id = parsed['id'];
  if (hasError && (id === undefined || id === null)) {
    // Apex omits the id on errors raised before it could read one; the HTTP
    // exchange itself ties the error to this request.
    return { kind: 'write', line: withId(compactJson(text), requestId) };
  }
  if (id !== requestId) {
    return { kind: 'local', reason: 'The remote endpoint answered with a mismatched request id', httpStatus: status };
  }
  const line = compactJson(text);
  return protocolVersion === undefined ? { kind: 'write', line } : { kind: 'write', line, protocolVersion };
}

// ---------------------------------------------------------------------------
// Lossless JSON line handling
//
// JSON.stringify(JSON.parse(x)) corrupts large integers, long decimals and
// 1e999, so a validated body is never re-serialised. Whitespace outside
// strings is removed instead, and every token keeps its original spelling.
// ---------------------------------------------------------------------------

/**
 * Remove insignificant whitespace from JSON text that already parsed. Strings,
 * escapes and number spelling are untouched. The result is a single line.
 */
export function compactJson(text: string): string {
  let out = '';
  const parts: string[] = [];
  let start = 0;
  let inString = false;
  for (let i = 0; i < text.length; i++) {
    const c = text.charCodeAt(i);
    if (inString) {
      if (c === 0x5c) i++; // skip the escaped character
      else if (c === 0x22) inString = false;
    } else if (c === 0x22) {
      inString = true;
    } else if (c === 0x20 || c === 0x09 || c === 0x0a || c === 0x0d) {
      if (i > start) parts.push(text.slice(start, i));
      start = i + 1;
      if (parts.length >= 1024) {
        out += parts.join('');
        parts.length = 0;
      }
    }
  }
  if (start < text.length) parts.push(text.slice(start));
  return out + parts.join('');
}

/**
 * Give a compact JSON object the top-level `"id": id`, dropping any existing
 * top-level `id` member (null or duplicate). Every other member is copied
 * verbatim, so `error.data` is never re-serialised.
 */
function withId(compact: string, id: RequestId): string {
  const n = compact.length;
  let out = `{"id":${JSON.stringify(id)}`;
  let i = 1; // after the opening brace
  while (i < n - 1) {
    const start = i;
    let j = i + 1;
    while (compact.charCodeAt(j) !== 0x22) {
      if (compact.charCodeAt(j) === 0x5c) j++;
      j++;
    }
    const key = JSON.parse(compact.slice(i, j + 1)) as string;
    let k = j + 2; // skip the closing quote and the colon
    let depth = 0;
    let inString = false;
    for (; k < n; k++) {
      const c = compact.charCodeAt(k);
      if (inString) {
        if (c === 0x5c) k++;
        else if (c === 0x22) inString = false;
      } else if (c === 0x22) {
        inString = true;
      } else if (c === 0x7b || c === 0x5b) {
        depth++;
      } else if (c === 0x7d || c === 0x5d) {
        if (depth === 0) break;
        depth--;
      } else if (c === 0x2c && depth === 0) {
        break;
      }
    }
    if (key !== 'id') out += ',' + compact.slice(start, k);
    i = k + 1;
  }
  return out + '}';
}

// ---------------------------------------------------------------------------
// Error lines
// ---------------------------------------------------------------------------

/** Local proxy error (7.3). The reason must never contain tokens or remote bodies. */
export function localError(
  id: RequestId | null | undefined,
  reason: string,
  httpStatus: number | null
): string {
  const envelope: Record<string, unknown> = { jsonrpc: '2.0' };
  if (id !== undefined && id !== null) envelope['id'] = id;
  envelope['error'] = {
    code: -32603,
    message: `salesforce-mcp-lib proxy: ${reason}`,
    data: { source: PROXY_ERROR_SOURCE, httpStatus },
  };
  return JSON.stringify(envelope);
}

/** Standard JSON-RPC error line with no proxy marker (parse errors, invalid requests). */
export function protocolError(code: number, message: string, id?: RequestId): string {
  const envelope: Record<string, unknown> = { jsonrpc: '2.0' };
  if (id !== undefined) envelope['id'] = id;
  envelope['error'] = { code, message };
  return JSON.stringify(envelope);
}
