import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  LEGACY_VERSION,
  MODERN_VERSION,
  buildHeaders,
  classifyLine,
  encodeHeaderValue,
  interpretRemote,
  localError,
} from '../src/protocol.js';

const META = 'io.modelcontextprotocol/protocolVersion';

describe('constants', () => {
  it('exports the two protocol versions', () => {
    assert.equal(MODERN_VERSION, '2026-07-28');
    assert.equal(LEGACY_VERSION, '2025-11-25');
  });
});

describe('classifyLine retention (H1)', () => {
  it('keeps routing metadata and the raw line, never the parsed params', () => {
    const line = `{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"t","arguments":{"deep":[[[1,2,3]]]},"_meta":{"${META}":"2026-07-28"}}}`;
    const msg = classifyLine(line);
    assert.equal(msg.kind, 'request');
    assert.deepEqual(Object.keys(msg).sort(), ['headers', 'id', 'kind', 'method', 'raw']);
    assert.deepEqual((msg as { headers: unknown }).headers, { kind: 'modern', version: '2026-07-28', name: 't' });
    assert.equal((msg as { raw: string }).raw, line);
  });

  it('a notification has the same shape', () => {
    const msg = classifyLine('{"jsonrpc":"2.0","method":"notifications/initialized","params":{"x":[1]}}');
    assert.deepEqual(Object.keys(msg).sort(), ['headers', 'kind', 'method', 'raw']);
  });

  it('stores only the encoded name, so a structure-heavy params tree is not retained', () => {
    const heavy = '[' + '{},'.repeat(100_000) + '{}]';
    const msg = classifyLine(`{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{"a":${heavy}}}`);
    assert.ok(JSON.stringify(msg).length < 2_000_000);
    assert.ok(!('params' in msg));
  });

  it('rejects a method longer than 256 chars as an invalid request, with its id', () => {
    const msg = classifyLine(JSON.stringify({ jsonrpc: '2.0', id: 4, method: 'm'.repeat(257) }));
    assert.deepEqual(msg, { kind: 'invalid', id: 4, reason: 'Invalid Request' });
  });
});

describe('classifyLine (spec 7.1)', () => {
  it('not JSON is a parse error', () => {
    assert.deepEqual(classifyLine('{nope'), { kind: 'parse-error' });
  });

  it('array is a batch', () => {
    assert.deepEqual(classifyLine('[{"jsonrpc":"2.0","id":1,"method":"x"}]'), { kind: 'batch' });
  });

  for (const line of ['1', '"x"', 'null', 'true']) {
    it(`JSON scalar ${line} is an invalid request, not a parse error`, () => {
      assert.equal(classifyLine(line).kind, 'invalid');
    });
  }

  it('object with result or error and an id is a dropped client response', () => {
    assert.equal(classifyLine('{"jsonrpc":"2.0","id":1,"result":{}}').kind, 'drop');
    assert.equal(classifyLine('{"jsonrpc":"2.0","id":1,"error":{"code":1,"message":"m"}}').kind, 'drop');
  });

  it('object with neither method nor result/error is invalid, not a response', () => {
    assert.equal(classifyLine('{"jsonrpc":"2.0","id":1}').kind, 'invalid');
    assert.equal(classifyLine('{}').kind, 'invalid');
  });

  it('non-string method, wrong jsonrpc are invalid and echo a valid id', () => {
    assert.deepEqual(classifyLine('{"jsonrpc":"2.0","id":4,"method":5}'), { kind: 'invalid', id: 4, reason: 'Invalid Request' });
    assert.deepEqual(classifyLine('{"jsonrpc":"1.0","id":"a","method":"x"}'), { kind: 'invalid', id: 'a', reason: 'Invalid Request' });
  });

  for (const id of ['null', '1.5', 'true', '[]', '{}', '1e300']) {
    it(`request with id ${id} is rejected as invalid`, () => {
      const msg = classifyLine(`{"jsonrpc":"2.0","id":${id},"method":"x"}`);
      assert.equal(msg.kind, 'invalid');
      assert.equal((msg as { id?: unknown }).id, undefined);
    });
  }

  it('classifies string and integral ids as requests', () => {
    const a = classifyLine('{"jsonrpc":"2.0","id":"7","method":"tools/list"}');
    const b = classifyLine('{"jsonrpc":"2.0","id":0,"method":"tools/list","params":{"a":1}}');
    assert.equal(a.kind, 'request');
    assert.equal((a as { id: unknown }).id, '7');
    assert.equal((b as { id: unknown }).id, 0);
  });

  it('keeps the raw line for forwarding', () => {
    const line = '{"jsonrpc":"2.0", "id":1, "method":"x"}';
    assert.equal((classifyLine(line) as { raw: string }).raw, line);
  });

  it('notifications/cancelled is local, keeping string and number ids distinct', () => {
    assert.deepEqual(
      classifyLine('{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":"1"}}'),
      { kind: 'cancel', requestId: '1' }
    );
    assert.deepEqual(
      classifyLine('{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":1}}'),
      { kind: 'cancel', requestId: 1 }
    );
  });

  it('cancellation without a usable requestId is dropped', () => {
    assert.equal(classifyLine('{"jsonrpc":"2.0","method":"notifications/cancelled","params":{}}').kind, 'drop');
    assert.equal(classifyLine('{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":null}}').kind, 'drop');
  });

  it('other notifications are forwarded', () => {
    assert.equal(classifyLine('{"jsonrpc":"2.0","method":"notifications/initialized"}').kind, 'notification');
  });
});

describe('encodeHeaderValue (S-HTTP table)', () => {
  const b64 = (s: string): string => `=?base64?${Buffer.from(s, 'utf8').toString('base64')}?=`;
  const cases: [string, string][] = [
    ['us-west1', 'us-west1'],
    ['has space inside', 'has space inside'],
    ['Hello, 世界', b64('Hello, 世界')],
    [' padded ', b64(' padded ')],
    ['line1\nline2', b64('line1\nline2')],
    ['tab\there', b64('tab\there')],
    ['=?base64?literal?=', b64('=?base64?literal?=')],
  ];
  for (const [input, expected] of cases) {
    it(`${JSON.stringify(input)}`, () => {
      assert.equal(encodeHeaderValue(input), expected);
    });
  }
});

describe('buildHeaders (spec 7.2)', () => {
  const modern = (method: string, params: Record<string, unknown> = {}) => ({
    method,
    params: { ...params, _meta: { [META]: MODERN_VERSION } },
  });

  it('modern request gets version and method', () => {
    assert.deepEqual(buildHeaders(modern('tools/list'), LEGACY_VERSION), {
      ok: true,
      headers: { 'MCP-Protocol-Version': MODERN_VERSION, 'Mcp-Method': 'tools/list' },
    });
  });

  it('tools/call and prompts/get add Mcp-Name from params.name', () => {
    for (const method of ['tools/call', 'prompts/get']) {
      const r = buildHeaders(modern(method, { name: 'search' }), null);
      assert.ok(r.ok && r.headers['Mcp-Name'] === 'search');
    }
  });

  it('resources/read adds Mcp-Name from params.uri', () => {
    const r = buildHeaders(modern('resources/read', { uri: 'acme://a/1' }), null);
    assert.ok(r.ok && r.headers['Mcp-Name'] === 'acme://a/1');
  });

  it('omits Mcp-Name when the value is not a string or the method does not use it', () => {
    const a = buildHeaders(modern('tools/call', { name: 5 }), null);
    const b = buildHeaders(modern('tools/list', { name: 'x' }), null);
    assert.ok(a.ok && !('Mcp-Name' in a.headers));
    assert.ok(b.ok && !('Mcp-Name' in b.headers));
  });

  it('initialize gets no headers even when the legacy version is known', () => {
    assert.deepEqual(buildHeaders({ method: 'initialize', params: {} }, LEGACY_VERSION), { ok: true, headers: {} });
  });

  it('other messages get the legacy version when known, nothing otherwise', () => {
    assert.deepEqual(buildHeaders({ method: 'tools/list' }, LEGACY_VERSION), {
      ok: true,
      headers: { 'MCP-Protocol-Version': LEGACY_VERSION },
    });
    assert.deepEqual(buildHeaders({ method: 'tools/list' }, null), { ok: true, headers: {} });
  });

  it('a malformed _meta version is rejected and never inherits the legacy version', () => {
    for (const bad of [5, null, true, {}, [], '', 'x'.repeat(300), '2026 07 28']) {
      const r = buildHeaders({ method: 'tools/list', params: { _meta: { [META]: bad } } }, LEGACY_VERSION);
      assert.equal(r.ok, false, `accepted ${JSON.stringify(bad)}`);
    }
  });

  it('a _meta without the version key, or a non-object _meta, is legacy', () => {
    for (const meta of [{}, { other: 1 }, 'x', null, []]) {
      const r = buildHeaders({ method: 'tools/list', params: { _meta: meta } }, LEGACY_VERSION);
      assert.deepEqual(r, { ok: true, headers: { 'MCP-Protocol-Version': LEGACY_VERSION } });
    }
  });

  it('rejects a name or uri too long for a header', () => {
    assert.equal(buildHeaders(modern('tools/call', { name: 'n'.repeat(2049) }), null).ok, false);
    assert.equal(buildHeaders(modern('tools/call', { name: 'n'.repeat(2048) }), null).ok, true);
  });

  it('rejects a modern method or version outside visible ASCII', () => {
    assert.equal(buildHeaders(modern('tools/cäll'), null).ok, false);
    assert.equal(
      buildHeaders({ method: 'x', params: { _meta: { [META]: '2026-07-28\r\nX: y' } } }, null).ok,
      false
    );
  });
});

describe('interpretRemote (spec 7.3)', () => {
  const ok = '{"jsonrpc":"2.0","id":1,"result":{"a":1}}';

  it('writes a valid result envelope', () => {
    assert.deepEqual(interpretRemote(200, ok, 1), { kind: 'write', line: ok });
  });

  it('writes any-status error envelopes', () => {
    const body = '{"jsonrpc":"2.0","id":"x","error":{"code":-32020,"message":"m"}}';
    for (const status of [200, 400, 404]) {
      assert.deepEqual(interpretRemote(status, body, 'x'), { kind: 'write', line: body });
    }
  });

  it('notifications are always silent, with a warning for non-2xx', () => {
    assert.deepEqual(interpretRemote(202, '', undefined), { kind: 'silent' });
    assert.deepEqual(interpretRemote(204, '', undefined), { kind: 'silent' });
    assert.deepEqual(interpretRemote(200, ok, undefined), { kind: 'silent' });
    assert.equal((interpretRemote(500, 'boom', undefined) as { warn?: string }).warn, 'notification POST returned HTTP 500');
  });

  it('a request with empty 202/204/200 is a local error', () => {
    for (const status of [200, 202, 204]) {
      const r = interpretRemote(status, '', 1);
      assert.equal(r.kind, 'local');
      assert.equal((r as { httpStatus: number }).httpStatus, status);
    }
  });

  it('non-envelope bodies are local errors that do not carry the body', () => {
    for (const body of ['<html>x</html>', '[{"errorCode":"X","message":"leak"}]', '"str"', '{"result":1}']) {
      const r = interpretRemote(500, body, 1);
      assert.equal(r.kind, 'local');
      assert.ok(!JSON.stringify(r).includes('leak'));
    }
  });

  it('rejects wrong ids, including string vs number', () => {
    assert.equal(interpretRemote(200, '{"jsonrpc":"2.0","id":2,"result":{}}', 1).kind, 'local');
    assert.equal(interpretRemote(200, '{"jsonrpc":"2.0","id":"1","result":{}}', 1).kind, 'local');
    assert.equal(interpretRemote(200, '{"jsonrpc":"2.0","id":1,"result":{}}', '1').kind, 'local');
    assert.equal(interpretRemote(200, '{"jsonrpc":"2.0","id":null,"result":{}}', 1).kind, 'local');
  });

  it('rejects result/error exclusivity violations and bad error shapes', () => {
    assert.equal(interpretRemote(200, '{"jsonrpc":"2.0","id":1,"result":1,"error":{"code":1,"message":"m"}}', 1).kind, 'local');
    assert.equal(interpretRemote(200, '{"jsonrpc":"2.0","id":1}', 1).kind, 'local');
    assert.equal(interpretRemote(200, '{"jsonrpc":"2.0","id":1,"error":"x"}', 1).kind, 'local');
    assert.equal(interpretRemote(200, '{"jsonrpc":"2.0","id":1,"error":{"code":"1","message":"m"}}', 1).kind, 'local');
  });

  it('adds the request id to an error that has none or null', () => {
    for (const idPart of ['', '"id":null,']) {
      const r = interpretRemote(400, `{"jsonrpc":"2.0",${idPart}"error":{"code":-32600,"message":"m"}}`, 9);
      assert.equal(r.kind, 'write');
      assert.equal(JSON.parse((r as { line: string }).line).id, 9);
    }
  });

  it('collapses a multi-line body to one line', () => {
    const r = interpretRemote(200, '{\n"jsonrpc":"2.0",\n"id":1,\n"result":{}\n}', 1);
    assert.deepEqual(r, { kind: 'write', line: '{"jsonrpc":"2.0","id":1,"result":{}}' });
  });

  it('reports the protocolVersion of a result for the legacy header', () => {
    const r = interpretRemote(200, '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-11-25"}}', 1);
    assert.equal((r as { protocolVersion?: string }).protocolVersion, '2025-11-25');
  });
});

describe('lossless numbers and strings (M2)', () => {
  const NUMBERS = '[12345678901234567890,0.1000000000000000055511151231257827,1e999,1.0,-0,1E+2,123456789012345678901234567890.5]';
  const ROUNDTRIP_LOSSY = JSON.stringify(JSON.parse(NUMBERS));

  it('premise: stringify(parse()) corrupts these numbers', () => {
    assert.notEqual(ROUNDTRIP_LOSSY, NUMBERS);
  });

  it('keeps every numeric lexeme from a single-line body', () => {
    const body = `{"jsonrpc":"2.0","id":1,"result":{"n":${NUMBERS}}}`;
    assert.deepEqual(interpretRemote(200, body, 1), { kind: 'write', line: body });
  });

  it('keeps every numeric lexeme from a multi-line body', () => {
    const body = `{\n  "jsonrpc": "2.0",\r\n\t"id": 1,\n  "result": {\n    "n": [\n 12345678901234567890 ,\n 0.1000000000000000055511151231257827,\n 1e999 ] }\n}\n`;
    const r = interpretRemote(200, body, 1) as { kind: string; line: string };
    assert.equal(r.kind, 'write');
    assert.equal(
      r.line,
      '{"jsonrpc":"2.0","id":1,"result":{"n":[12345678901234567890,0.1000000000000000055511151231257827,1e999]}}'
    );
  });

  it('keeps whitespace, escapes and unicode inside strings, removes it outside', () => {
    const value = '"a  b\\n\\t \\"q\\" \\\\ \\u00e9 \\ud83d\\ude00 é 😀 {  }  ,  :  "';
    const body = `{ "jsonrpc" : "2.0" , "id" : 1 , "result" : { "k  ey" : ${value} } }`;
    const r = interpretRemote(200, body, 1) as { line: string };
    assert.equal(r.line, `{"jsonrpc":"2.0","id":1,"result":{"k  ey":${value}}}`);
    assert.equal(JSON.parse(r.line).result['k  ey'], JSON.parse(value));
  });

  it('a string ending in backslashes does not end early', () => {
    const body = '{ "jsonrpc":"2.0", "id":1, "result": "x\\\\" }';
    assert.equal((interpretRemote(200, body, 1) as { line: string }).line, '{"jsonrpc":"2.0","id":1,"result":"x\\\\"}');
  });

  it('injects the id into an error without re-serialising error.data', () => {
    const data = `{"big":12345678901234567890,"d":0.1000000000000000055511151231257827,"inf":1e999,"s":"a  b"}`;
    const missing = `{\n "jsonrpc":"2.0",\n "error":{"code":-32600,"message":"m","data":${data}}\n}`;
    const nullId = `{"jsonrpc":"2.0","id" : null,"error":{"code":-32600,"message":"m","data":${data}}}`;
    for (const body of [missing, nullId]) {
      const r = interpretRemote(400, body, 'abc') as { line: string };
      assert.equal(
        r.line,
        `{"id":"abc","jsonrpc":"2.0","error":{"code":-32600,"message":"m","data":${data}}}`
      );
    }
  });

  it('drops an escaped or duplicated top-level id key when injecting', () => {
    const body = '{"jsonrpc":"2.0","id":7,"\\u0069d":null,"error":{"code":1,"message":"m","id":{"x":[1,2]}}}';
    const r = interpretRemote(200, body, 3) as { line: string };
    assert.equal(r.line, '{"id":3,"jsonrpc":"2.0","error":{"code":1,"message":"m","id":{"x":[1,2]}}}');
  });

  it('keeps the strict id check for results and for errors with a real id', () => {
    assert.equal(interpretRemote(200, '{"jsonrpc":"2.0","result":{}}', 1).kind, 'local');
    assert.equal(interpretRemote(200, '{"jsonrpc":"2.0","id":2,"error":{"code":1,"message":"m"}}', 1).kind, 'local');
  });
});

describe('localError (spec 7.3)', () => {
  it('has the documented shape', () => {
    assert.deepEqual(JSON.parse(localError(3, 'timed out', null)), {
      jsonrpc: '2.0',
      id: 3,
      error: {
        code: -32603,
        message: 'salesforce-mcp-lib proxy: timed out',
        data: { source: 'salesforce-mcp-lib-proxy', httpStatus: null },
      },
    });
  });

  it('omits the id when unknown and keeps the status', () => {
    const parsed = JSON.parse(localError(undefined, 'x', 502));
    assert.ok(!('id' in parsed));
    assert.equal(parsed.error.data.httpStatus, 502);
  });

  it('contains no token and stays one line', () => {
    const line = localError('a\nb', 'The remote endpoint returned an unexpected status (HTTP 503)', 503);
    assert.ok(!line.includes('\n'));
    assert.ok(!/bearer|token|secret/i.test(line));
  });
});
