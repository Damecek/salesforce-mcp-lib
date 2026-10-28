import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import http from 'node:http';
import type { AddressInfo } from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const packageDir = fileURLToPath(new URL('..', import.meta.url));
const npmCmd = process.platform === 'win32' ? 'npm.cmd' : 'npm';
const CLIENT_SECRET = 'smoke-client-secret-value';
const ACCESS_TOKEN = 'smoke-access-token-0123456789abcdef';
const INITIALIZE = {
  jsonrpc: '2.0',
  id: 1,
  method: 'initialize',
  params: {
    protocolVersion: '2025-11-25',
    capabilities: {},
    clientInfo: { name: 'smoke', version: '0.0.0' },
  },
};
const INITIALIZE_RESULT = {
  jsonrpc: '2.0',
  id: 1,
  result: {
    protocolVersion: '2025-11-25',
    capabilities: { tools: {} },
    serverInfo: { name: 'mock-apex', version: '0.0.1' },
  },
};
const META_VERSION = 'io.modelcontextprotocol/protocolVersion';
const DISCOVER = {
  jsonrpc: '2.0',
  id: 'd1',
  method: 'server/discover',
  params: {
    _meta: {
      [META_VERSION]: '2026-07-28',
      'io.modelcontextprotocol/clientCapabilities': {},
    },
  },
};
const DISCOVER_RESULT = {
  jsonrpc: '2.0',
  id: 'd1',
  result: {
    resultType: 'complete',
    supportedVersions: ['2026-07-28', '2025-11-25'],
    capabilities: { tools: {} },
    ttlMs: 0,
    cacheScope: 'private',
    _meta: { 'io.modelcontextprotocol/serverInfo': { name: 'mock-apex', version: '0.0.1' } },
  },
};
const INITIALIZED = { jsonrpc: '2.0', method: 'notifications/initialized' };

function run(cmd: string, args: string[], cwd: string, env: NodeJS.ProcessEnv) {
  const r = spawnSync(cmd, args, { cwd, env, encoding: 'utf8', timeout: 120_000 });
  assert.equal(r.status, 0, `${cmd} ${args.join(' ')} failed:\n${r.stdout}\n${r.stderr}`);
  return r.stdout;
}

describe('npm tarball consumer smoke', () => {
  let tmp: string;
  let consumerDir: string;
  let server: http.Server;
  let baseUrl: string;
  const tokenRequests: string[] = [];
  const apexRequests: { auth: string | undefined; body: string; headers: http.IncomingHttpHeaders }[] = [];
  let env: NodeJS.ProcessEnv;
  let tarballFiles: string[];

  before(async () => {
    tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'sfmcp-consumer-'));
    env = {
      ...process.env,
      HOME: path.join(tmp, 'home'),
      SALESFORCE_MCP_LIB_STORAGE_DIR: path.join(tmp, 'tokens'),
      npm_config_cache: path.join(tmp, 'npm-cache'),
    };
    for (const k of ['SF_INSTANCE_URL', 'SF_CLIENT_ID', 'SF_CLIENT_SECRET', 'SF_ENDPOINT']) {
      delete env[k];
    }

    const packDir = path.join(tmp, 'pack');
    fs.mkdirSync(packDir);
    // No --ignore-scripts: `prepack` rebuilds dist/, so the tarball never carries a stale build.
    const packJson = JSON.parse(
      run(npmCmd, ['pack', '--json', '--pack-destination', packDir], packageDir, env)
    ) as { filename: string; files: { path: string }[] }[];
    tarballFiles = packJson[0]!.files.map((f) => f.path);

    consumerDir = path.join(tmp, 'consumer');
    fs.mkdirSync(consumerDir);
    fs.writeFileSync(path.join(consumerDir, 'package.json'), '{"name":"consumer","private":true}');
    run(
      npmCmd,
      ['install', path.join(packDir, packJson[0]!.filename), '--omit=dev', '--offline', '--ignore-scripts', '--no-audit', '--no-fund'],
      consumerDir,
      env
    );

    server = http.createServer((req, res) => {
      const chunks: Buffer[] = [];
      req.on('data', (c: Buffer) => chunks.push(c));
      req.on('end', () => {
        const body = Buffer.concat(chunks).toString('utf8');
        res.setHeader('Content-Type', 'application/json');
        if (req.url === '/services/oauth2/token') {
          tokenRequests.push(body);
          res.end(JSON.stringify({ access_token: ACCESS_TOKEN, instance_url: baseUrl, token_type: 'Bearer', id: '', issued_at: '1' }));
        } else if (req.url === '/services/apexrest/mcp') {
          apexRequests.push({ auth: req.headers.authorization, body, headers: req.headers });
          const method = (JSON.parse(body) as { method?: string }).method;
          if (method === 'notifications/initialized') {
            res.statusCode = 202;
            res.end();
          } else if (method === 'server/discover') {
            res.end(JSON.stringify(DISCOVER_RESULT));
          } else {
            res.end(JSON.stringify(INITIALIZE_RESULT));
          }
        } else {
          res.statusCode = 404;
          res.end('{}');
        }
      });
    });
    await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
    baseUrl = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
  });

  after(async () => {
    if (server) {
      server.closeAllConnections();
      await new Promise<void>((resolve) => server.close(() => resolve()));
    }
    fs.rmSync(tmp, { recursive: true, force: true });
  });

  it('packs only dist/ and installs with no runtime dependencies', () => {
    assert.ok(tarballFiles.includes('dist/index.js'));
    assert.ok(tarballFiles.every((f) => f === 'package.json' || f === 'README.md' || f === 'LICENSE' || f.startsWith('dist/')), tarballFiles.join(', '));

    const installed = JSON.parse(
      fs.readFileSync(path.join(consumerDir, 'node_modules', 'salesforce-mcp-lib', 'package.json'), 'utf8')
    ) as Record<string, unknown>;
    assert.equal(installed['dependencies'], undefined);
    assert.deepEqual(
      fs.readdirSync(path.join(consumerDir, 'node_modules')).filter((n) => !n.startsWith('.')),
      ['salesforce-mcp-lib']
    );
  });

  /** Start the installed bin, send the lines, close stdin and wait for the drained exit. */
  async function runProxy(inputs: unknown[]) {
    tokenRequests.length = 0;
    apexRequests.length = 0;
    const bin = path.join(consumerDir, 'node_modules', '.bin', 'salesforce-mcp-lib');
    const child = spawn(
      bin,
      ['--instance-url', baseUrl, '--client-id', 'smoke-client-id', '--client-secret', CLIENT_SECRET, '--endpoint', '/services/apexrest/mcp'],
      { cwd: consumerDir, env, stdio: ['pipe', 'pipe', 'pipe'] }
    );
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (d: Buffer) => (stdout += d.toString()));
    child.stderr.on('data', (d: Buffer) => (stderr += d.toString()));
    const killer = setTimeout(() => child.kill('SIGKILL'), 10_000);
    const exited = new Promise<{ code: number | null; signal: NodeJS.Signals | null }>((resolve, reject) => {
      child.on('error', reject);
      child.on('close', (code, signal) => resolve({ code, signal }));
    });

    // Closing stdin right away also proves the proxy drains in-flight requests before exiting.
    child.stdin.end(inputs.map((m) => JSON.stringify(m) + '\n').join(''));
    const { code, signal } = await exited;
    clearTimeout(killer);
    assert.equal(signal, null, `killed by timeout; stderr:\n${stderr}`);
    assert.equal(code, 0, stderr);
    for (const secret of [CLIENT_SECRET, ACCESS_TOKEN]) {
      assert.ok(!stdout.includes(secret), 'secret leaked to stdout');
      assert.ok(!stderr.includes(secret), 'secret leaked to stderr');
    }
    return { lines: stdout.split('\n').filter((l) => l.length > 0), stderr };
  }

  it('installed bin answers a legacy initialize round trip over stdio', async () => {
    const { lines } = await runProxy([INITIALIZE]);

    assert.equal(lines.length, 1, 'stdout must hold only the JSON-RPC response');
    assert.deepEqual(JSON.parse(lines[0]!), INITIALIZE_RESULT);
    assert.equal(tokenRequests.length, 1);
    assert.match(tokenRequests[0]!, /grant_type=client_credentials/);
    assert.equal(apexRequests.length, 1);
    assert.equal(apexRequests[0]!.auth, `Bearer ${ACCESS_TOKEN}`);
    assert.deepEqual(JSON.parse(apexRequests[0]!.body), INITIALIZE);
    assert.equal(apexRequests[0]!.headers['mcp-protocol-version'], undefined);
  });

  it('installed bin does modern discovery and keeps notifications silent', async () => {
    const { lines } = await runProxy([DISCOVER, INITIALIZED]);

    assert.equal(lines.length, 1, `the 202 notification must add no output, got: ${lines.join(' | ')}`);
    assert.deepEqual(JSON.parse(lines[0]!), DISCOVER_RESULT);
    assert.equal(apexRequests.length, 2);
    const discover = apexRequests.find((r) => (JSON.parse(r.body) as { method: string }).method === 'server/discover')!;
    assert.equal(discover.headers['mcp-protocol-version'], '2026-07-28');
    assert.equal(discover.headers['mcp-method'], 'server/discover');
    assert.deepEqual(JSON.parse(discover.body), DISCOVER, 'modern _meta must reach Apex unchanged');
    const notification = apexRequests.find((r) => (JSON.parse(r.body) as { method: string }).method === 'notifications/initialized')!;
    assert.equal(notification.headers['mcp-protocol-version'], undefined);
  });
});
