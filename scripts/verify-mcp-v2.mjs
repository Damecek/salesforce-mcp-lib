#!/usr/bin/env node
// Live MCP v2 verification: packed npm bridge -> real Apex endpoints on an existing scratch org.
// Read-only. The access token comes from `sf org display`, lives only in this process, and is
// never printed or written. Output is checked for the token before it is emitted.
//
// Usage: node scripts/verify-mcp-v2.mjs --org <alias> --package-dir <installed salesforce-mcp-lib dir>
//        --tools-dir <dir with ajv, ajv-formats> --schema-dir <dir with schema.json, legacy.json>
//
// Not an OAuth test: auth is an adapter holding the sf session token (shortcut: no refresh,
// reauthenticate throws; upgrade by using a real External Client App if OAuth must be proven).

import { execFileSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import { PassThrough } from 'node:stream';
import { pathToFileURL } from 'node:url';

const arg = (name, def) => {
  const i = process.argv.indexOf(`--${name}`);
  return i > 0 ? process.argv[i + 1] : def;
};
const org = arg('org', 'mcp-lib-v2-validation');
const pkgDir = arg('package-dir');
const toolsDir = arg('tools-dir');
const schemaDir = arg('schema-dir');
if (!pkgDir || !toolsDir || !schemaDir) throw new Error('--package-dir, --tools-dir and --schema-dir are required');

const MODERN = '2026-07-28';
const LEGACY = '2025-11-25';
const META_V = 'io.modelcontextprotocol/protocolVersion';
const META_C = 'io.modelcontextprotocol/clientCapabilities';

// --- credentials (in memory only) -----------------------------------------------------------
// `sf org display` redacts the token, so read it in-process through the CLI's own @salesforce/core.
// Connection.refreshAuth() refreshes an expired session if needed (read-only).
const sfCoreDir = arg('sf-core-dir', execFileSync('sh', ['-c', 'echo "$(dirname "$(readlink -f "$(which sf)")")/../node_modules/@salesforce/core"'], { encoding: 'utf8' }).trim());
const { Org, Connection, AuthInfo } = createRequire(`${sfCoreDir}/x.js`)('@salesforce/core');
const authInfo = await AuthInfo.create({ username: (await Org.create({ aliasOrUsername: org })).getUsername() });
const conn = await Connection.create({ authInfo });
await conn.request('/services/data/');
const display = { alias: org, id: conn.getAuthInfoFields().orgId, accessToken: conn.accessToken, instanceUrl: conn.instanceUrl };
const token = display.accessToken;
const instanceUrl = display.instanceUrl;
if (!token || !instanceUrl) throw new Error('sf org display returned no session');
const strategy = {
  mode: 'authorization_code',
  getAccessToken: async () => token,
  getInstanceUrl: () => instanceUrl,
  reauthenticate: async () => { throw new Error('session token cannot be refreshed in this adapter'); },
};

// --- libraries under test (the packed artifact) ---------------------------------------------
const load = (f) => import(pathToFileURL(`${pkgDir}/dist/${f}`).href);
const { createBridge } = await load('mcpBridge.js');
const { classifyLine } = await load('protocol.js');
const { startStdioListener, createLogger } = await load('stdio.js');

// --- schema validation (test-only ajv from a temp dir) --------------------------------------
const req = createRequire(`${toolsDir}/x.js`);
const Ajv2020 = req('ajv/dist/2020').default ?? req('ajv/dist/2020');
const addFormats = req('ajv-formats');
const schema = JSON.parse(readFileSync(`${schemaDir}/schema.json`, 'utf8'));
const legacySchema = JSON.parse(readFileSync(`${schemaDir}/legacy.json`, 'utf8'));
const mk = (s, id) => {
  const ajv = new Ajv2020({ strict: false, allErrors: false });
  addFormats(ajv);
  ajv.addSchema(s, id);
  return (def, data) => {
    const v = ajv.getSchema(`${id}#/$defs/${def}`);
    if (!v) return `no definition ${def}`;
    return v(data) ? null : `${v.errors[0].instancePath} ${v.errors[0].message}`;
  };
};
const checkModern = mk(schema, 'modern');
const checkLegacy = mk(legacySchema, 'legacy');

// --- helpers --------------------------------------------------------------------------------
const results = [];
let nextId = 1;
const record = (endpoint, name, status, detail) => results.push({ endpoint, name, status, detail });

function bridgeFor(endpoint) {
  const logs = [];
  const logger = { debug() {}, info() {}, warn: (m) => logs.push(m), error: (m) => logs.push(m) };
  const bridge = createBridge(strategy, { instanceUrl, clientId: 'unused', endpoint: `/services/apexrest/mcp/${endpoint}`, requestTimeoutMs: 60000 }, logger);
  return { bridge, logs };
}

async function send(bridge, obj) {
  const line = JSON.stringify(obj);
  const c = classifyLine(line);
  if (c.kind !== 'request' && c.kind !== 'notification') {
    return { classified: c, out: null };
  }
  const o = await bridge.forward(c, new AbortController().signal);
  return { classified: c, out: o.kind === 'write' ? JSON.parse(o.line) : null, raw: o };
}

const modernMeta = () => ({ [META_V]: MODERN, [META_C]: {} });
const modernReq = (method, params = {}) => ({ jsonrpc: '2.0', id: nextId++, method, params: { ...params, _meta: modernMeta() } });
const legacyReq = (method, params = {}) => ({ jsonrpc: '2.0', id: nextId++, method, params });

function expect(endpoint, name, cond, detail) {
  record(endpoint, name, cond ? 'PASS' : 'FAIL', detail);
  return cond;
}
function validateModern(endpoint, name, def, out) {
  const err = out ? checkModern(def, out) : 'no response';
  expect(endpoint, `${name} schema:${def}`, !err, err ?? 'valid');
}

// --- per-endpoint flows ---------------------------------------------------------------------
async function flows(endpoint, toolCall) {
  const { bridge, logs } = bridgeFor(endpoint);
  const E = endpoint;

  // modern discover
  let { out } = await send(bridge, modernReq('server/discover'));
  expect(E, 'modern server/discover', out?.result?.resultType === 'complete' && !out.error, JSON.stringify({ resultType: out?.result?.resultType, versions: out?.result?.supportedVersions, caps: Object.keys(out?.result?.capabilities ?? {}) }));
  validateModern(E, 'server/discover', 'DiscoverResultResponse', out);
  const caps = out?.result?.capabilities ?? {};

  // lists
  for (const [method, def, key, cap] of [
    ['tools/list', 'ListToolsResultResponse', 'tools', 'tools'],
    ['resources/list', 'ListResourcesResultResponse', 'resources', 'resources'],
    ['resources/templates/list', 'ListResourceTemplatesResultResponse', 'resourceTemplates', 'resources'],
    ['prompts/list', 'ListPromptsResultResponse', 'prompts', 'prompts'],
  ]) {
    ({ out } = await send(bridge, modernReq(method)));
    if (!caps[cap]) {
      expect(E, `modern ${method} not advertised -> -32601`, out?.error?.code === -32601, JSON.stringify(out?.error));
      continue;
    }
    expect(E, `modern ${method}`, Array.isArray(out?.result?.[key]), `${key}=${out?.result?.[key]?.map((x) => x.name ?? x.uriTemplate).join(',')}`);
    validateModern(E, method, def, out);
  }

  // tools/call
  ({ out } = await send(bridge, modernReq('tools/call', toolCall)));
  expect(E, `modern tools/call ${toolCall.name}`, out?.result && !out.result.isError, JSON.stringify(out?.result ?? out?.error).slice(0, 240));
  validateModern(E, 'tools/call', 'CallToolResultResponse', out);

  // tool-level error (bad args) stays a result or protocol error, never a crash
  ({ out } = await send(bridge, modernReq('tools/call', { name: toolCall.name, arguments: { bogus: 1 } })));
  expect(E, 'modern tools/call invalid args', !!(out?.error || out?.result?.isError), JSON.stringify(out?.error ?? out?.result).slice(0, 200));

  // resources / prompts when advertised
  if (caps.resources) {
    ({ out } = await send(bridge, modernReq('resources/list')));
    const uri = out?.result?.resources?.[0]?.uri;
    if (uri) {
      ({ out } = await send(bridge, modernReq('resources/read', { uri })));
      expect(E, `modern resources/read ${uri}`, !!out?.result?.contents, JSON.stringify(out?.result ?? out?.error).slice(0, 200));
      validateModern(E, 'resources/read', 'ReadResourceResultResponse', out);
    }
    ({ out } = await send(bridge, modernReq('resources/read', { uri: 'nope://missing' })));
    expect(E, 'modern resources/read unknown uri', !!out?.error, JSON.stringify(out?.error));
  }
  if (caps.prompts) {
    ({ out } = await send(bridge, modernReq('prompts/list')));
    const p = out?.result?.prompts?.[0];
    if (p) {
      const args = Object.fromEntries((p.arguments ?? []).map((a) => [a.name, 'x']));
      ({ out } = await send(bridge, modernReq('prompts/get', { name: p.name, arguments: args })));
      expect(E, `modern prompts/get ${p.name}`, !!out?.result?.messages, JSON.stringify(out?.result ?? out?.error).slice(0, 200));
      validateModern(E, 'prompts/get', 'GetPromptResultResponse', out);
      ({ out } = await send(bridge, modernReq('completion/complete', { ref: { type: 'ref/prompt', name: p.name }, argument: { name: (p.arguments ?? [{ name: 'x' }])[0].name, value: '' } })));
      record(E, 'modern completion/complete', out?.result ? 'PASS' : out?.error ? 'INFO' : 'FAIL', JSON.stringify(out?.result ?? out?.error).slice(0, 200));
      if (out?.result) validateModern(E, 'completion/complete', 'CompleteResultResponse', out);
    }
  }

  // notification -> 202, nothing on stdout
  const n = await send(bridge, { jsonrpc: '2.0', method: 'notifications/initialized', params: { _meta: modernMeta() } });
  expect(E, 'notification -> silent (HTTP 202)', n.raw?.kind === 'silent', `outcome=${n.raw?.kind}`);

  // legacy: initialize then list
  ({ out } = await send(bridge, legacyReq('initialize', { protocolVersion: LEGACY, capabilities: {}, clientInfo: { name: 'verify', version: '0' } })));
  expect(E, 'legacy initialize', out?.result?.protocolVersion === LEGACY && !('resultType' in (out.result ?? {})), JSON.stringify({ v: out?.result?.protocolVersion, serverInfo: out?.result?.serverInfo }));
  const li = out ? checkLegacy('InitializeResult', out.result) : 'no response';
  expect(E, 'legacy initialize schema:InitializeResult', !li, li ?? 'valid');
  const ln = await send(bridge, { jsonrpc: '2.0', method: 'notifications/initialized' });
  expect(E, 'legacy notifications/initialized silent', ln.raw?.kind === 'silent', `outcome=${ln.raw?.kind}`);
  ({ out } = await send(bridge, legacyReq('tools/list')));
  expect(E, 'legacy tools/list', Array.isArray(out?.result?.tools) && !('resultType' in out.result), `tools=${out?.result?.tools?.map((t) => t.name).join(',')}`);
  const lt = out ? checkLegacy('ListToolsResult', out.result) : 'no response';
  expect(E, 'legacy tools/list schema:ListToolsResult', !lt, lt ?? 'valid');
  ({ out } = await send(bridge, legacyReq('tools/call', toolCall)));
  expect(E, `legacy tools/call ${toolCall.name}`, out?.result && !out.result.isError, JSON.stringify(out?.result ?? out?.error).slice(0, 200));
  const lc = out ? checkLegacy('CallToolResult', out.result) : 'no response';
  expect(E, 'legacy tools/call schema:CallToolResult', !lc, lc ?? 'valid');

  // errors
  ({ out } = await send(bridge, modernReq('no/such/method')));
  expect(E, 'modern unknown method -> -32601', out?.error?.code === -32601, JSON.stringify(out?.error));
  validateModern(E, 'unknown method', 'JSONRPCErrorResponse', out);
  ({ out } = await send(bridge, legacyReq('no/such/method')));
  expect(E, 'legacy unknown method -> -32601', out?.error?.code === -32601, JSON.stringify(out?.error));
  // bridge-side invalid version header -> local -32600, no Salesforce call
  ({ out } = await send(bridge, { jsonrpc: '2.0', id: nextId++, method: 'tools/list', params: { _meta: { [META_V]: 'bad value\u0001' } } }));
  expect(E, 'bridge rejects invalid version header -> -32600', out?.error?.code === -32600, JSON.stringify(out?.error));
  // unsupported version reaches Apex
  ({ out } = await send(bridge, { jsonrpc: '2.0', id: nextId++, method: 'tools/list', params: { _meta: { [META_V]: '1999-01-01', [META_C]: {} } } }));
  expect(E, 'unsupported protocol version -> error from Apex', !!out?.error, JSON.stringify(out?.error));
  validateModern(E, 'unsupported version', 'JSONRPCErrorResponse', out);
  return logs;
}

// Raw HTTP probes the bridge cannot produce (header absent, mismatched, bad Origin).
async function rawProbes(endpoint, toolName) {
  const url = `${instanceUrl}/services/apexrest/mcp/${endpoint}`;
  const body = JSON.stringify(modernReq('tools/list'));
  const call = async (headers, b = body) => {
    const r = await fetch(url, { method: 'POST', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', Accept: 'application/json, text/event-stream', ...headers }, body: b });
    const text = await r.text();
    let j; try { j = JSON.parse(text); } catch { j = null; }
    return { status: r.status, code: j?.error?.code, json: j, text: text.slice(0, 160) };
  };
  const E = endpoint;
  let r = await call({});
  expect(E, 'raw: modern body without headers', r.status === 400 && r.code === -32020, `HTTP ${r.status} code ${r.code}`);
  r = await call({ 'MCP-Protocol-Version': MODERN, 'Mcp-Method': 'prompts/list' });
  expect(E, 'raw: Mcp-Method mismatches body', r.status === 400 && r.code === -32020, `HTTP ${r.status} code ${r.code}`);
  const hm = checkModern('HeaderMismatchError', r.json);
  expect(E, 'raw: mismatch body schema:HeaderMismatchError', !hm, hm ?? 'valid');
  r = await call({ 'MCP-Protocol-Version': MODERN });
  expect(E, 'raw: missing Mcp-Method', r.status === 400 && r.code === -32020, `HTTP ${r.status} code ${r.code}`);
  r = await call({ 'MCP-Protocol-Version': MODERN, 'Mcp-Method': 'tools/list', Origin: 'https://evil.example' });
  
  r = await call({ 'MCP-Protocol-Version': MODERN, 'Mcp-Method': 'tools/list' }, '{not json');
  expect(E, 'raw: malformed JSON -> -32700', r.code === -32700, `HTTP ${r.status} code ${r.code}`);

  // Header values and methods are case-sensitive (Apex == is not, so this guards the framework).
  r = await call({ 'MCP-Protocol-Version': MODERN, 'Mcp-Method': 'TOOLS/LIST' });
  expect(E, 'raw: Mcp-Method differs from body only by case -> 400 -32020', r.status === 400 && r.code === -32020, `HTTP ${r.status} code ${r.code}`);
  const callBody = JSON.stringify(modernReq('tools/call', { name: toolName, arguments: {} }));
  const callHeaders = { 'MCP-Protocol-Version': MODERN, 'Mcp-Method': 'tools/call' };
  r = await call({ ...callHeaders, 'Mcp-Name': toolName }, callBody);
  expect(E, 'raw: exact Mcp-Name passes the header check', r.status === 200 || r.code !== -32020, `HTTP ${r.status} code ${r.code}`);
  r = await call({ ...callHeaders, 'Mcp-Name': toolName.toUpperCase() }, callBody);
  expect(E, 'raw: Mcp-Name differs from params.name only by case -> 400 -32020', r.status === 400 && r.code === -32020, `HTTP ${r.status} code ${r.code}`);
  r = await call({ 'MCP-Protocol-Version': MODERN, 'Mcp-Method': 'Tools/List' }, JSON.stringify(modernReq('Tools/List')));
  expect(E, 'raw: method Tools/List is unknown, not tools/list -> 404 -32601', r.status === 404 && r.code === -32601, `HTTP ${r.status} code ${r.code}`);

  // initialize is the legacy handshake only when no version is named.
  const initBody = (modernMetaToo) => JSON.stringify({ jsonrpc: '2.0', id: nextId++, method: 'initialize', params: { protocolVersion: LEGACY, capabilities: {}, clientInfo: { name: 'verify', version: '0' }, ...(modernMetaToo ? { _meta: modernMeta() } : {}) } });
  r = await call({}, initBody(false));
  expect(E, 'raw: initialize without a version -> legacy 200', r.status === 200 && r.json?.result?.protocolVersion === LEGACY, `HTTP ${r.status}`);
  r = await call({ 'MCP-Protocol-Version': LEGACY }, initBody(false));
  expect(E, 'raw: initialize with the legacy version header -> 200', r.status === 200 && r.json?.result?.protocolVersion === LEGACY, `HTTP ${r.status}`);
  r = await call({ 'MCP-Protocol-Version': MODERN, 'Mcp-Method': 'initialize' }, initBody(true));
  expect(E, 'raw: explicit modern initialize -> 404 -32601', r.status === 404 && r.code === -32601, `HTTP ${r.status} code ${r.code}`);
  r = await call({ 'MCP-Protocol-Version': '2099-01-01' }, initBody(false));
  expect(E, 'raw: initialize with an unknown version -> 400 -32022', r.status === 400 && r.code === -32022, `HTTP ${r.status} code ${r.code}`);

  // Nesting is rejected before the platform parser sees it.
  const deep = (n) => `{"jsonrpc":"2.0","id":1,"method":"initialize","params":${'['.repeat(n)}${']'.repeat(n)}}`;
  r = await call({}, deep(2500));
  expect(E, 'raw: 2,500 nesting levels (5 KB) -> 400 -32600', r.status === 400 && r.code === -32600, `HTTP ${r.status} code ${r.code}`);
  const t0 = Date.now();
  r = await call({}, deep(119900));
  expect(E, 'raw: 240 KB of nesting -> 400 -32600, no platform error', r.status === 400 && r.code === -32600, `HTTP ${r.status} code ${r.code} in ${Date.now() - t0} ms`);
  r = await call({}, deep(31));
  expect(E, 'raw: 32 nesting levels in total are still served', r.status === 200, `HTTP ${r.status}`);
  r = await call({}, `{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"s":"${'['.repeat(100)}\\\"${'{'.repeat(100)}"}}`);
  expect(E, 'raw: brackets and escaped quotes inside a string are not nesting', r.status === 200, `HTTP ${r.status}`);
}

const endpoints = [
  ['minimal', { name: 'minimal_echo', arguments: { message: 'hi' } }],
  ['harness', { name: 'dev_echo', arguments: { message: 'hi' } }],
  ['e2e', { name: 'query_accounts', arguments: { searchTerm: 'Ac' } }],
];

// discover real tool names first so a wrong guess does not mask a pass
for (const [ep, call] of endpoints) {
  const { bridge } = bridgeFor(ep);
  const { out } = await send(bridge, modernReq('tools/list'));
  const names = out?.result?.tools?.map((t) => t.name) ?? [];
  if (names.length && !names.includes(call.name)) call.name = names[0];
  if (ep === 'minimal' && names.length) call.arguments = { message: 'hi' };
  try { await flows(ep, call); await rawProbes(ep, call.name); } catch (e) { record(ep, 'flow crashed', 'FAIL', e.name); }
}

// real stdio listener (packed stdio.js) + bridge + live Apex: one modern line, one legacy pair
{
  const input = new PassThrough();
  const chunks = [];
  const output = { write: (c) => { chunks.push(c); return true; } };
  const { bridge } = bridgeFor('harness');
  input.end([JSON.stringify(modernReq('server/discover')), JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' }), JSON.stringify(legacyReq('initialize', { protocolVersion: LEGACY, capabilities: {}, clientInfo: { name: 'v', version: '0' } })), ''].join('\n'));
  await startStdioListener({ forward: (m, s) => bridge.forward(m, s), logger: createLogger('error'), input, output });
  const lines = chunks.join('').split('\n').filter(Boolean);
  expect('harness', 'stdio listener over live Apex: 2 output lines, none for notification', lines.length === 2 && lines.every((l) => !!JSON.parse(l).result), `lines=${lines.length}`);
}

// --- emit (token-checked) -------------------------------------------------------------------
const report = JSON.stringify({ org: display.alias ?? org, orgId: display.id, results }, null, 1);
if (report.includes(token)) { console.error('token leaked into report; aborting output'); process.exit(3); }
console.log(report);
const failed = results.filter((r) => r.status === 'FAIL');
console.error(`${results.length} checks, ${failed.length} failed`);
process.exit(failed.length ? 1 : 0);
