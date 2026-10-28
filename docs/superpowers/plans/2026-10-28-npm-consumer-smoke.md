# npm consumer smoke test plan

Goal: prove the built npm tarball works for a consumer, without importing `src/`.

Scope: one new file, `packages/salesforce-mcp-lib/tests/npmConsumer.smoke.test.ts`. No production, manifest, README or Salesforce changes.

## Seams used (no source changes)

- `SALESFORCE_MCP_LIB_STORAGE_DIR` isolates token storage.
- Client-credentials mode (`--client-secret`) with an `http://127.0.0.1` instance URL. `oauth.ts` and `mcpBridge.ts` already pick `node:http` by URL protocol.

## Steps

1. Ensure `dist/` exists (run the local `tsc` only if missing).
2. `npm pack --ignore-scripts --json --pack-destination <tmp>/pack` in the package dir.
3. Create an empty consumer dir with `{"private":true}`; `npm install <tgz> --omit=dev --offline --ignore-scripts --no-audit --no-fund` with an isolated npm cache.
4. Start a local mock: `POST /services/oauth2/token` and `POST /services/apexrest/mcp`.
5. Spawn `node_modules/.bin/salesforce-mcp-lib` with a 10 s kill timer, write one `initialize` line, read one stdout line, close stdin.

## Assertions

- Tarball contains `dist/index.js` and no `src/`, `tests/`.
- Installed `package.json` has no `dependencies`; `node_modules` holds only the package (plus `.bin`).
- Bin is executable and exits 0 after stdin closes.
- stdout is exactly one line equal to the mock's JSON-RPC result.
- Mock saw a `client_credentials` grant, a Bearer token on the Apex call, and an `initialize` request body.
- Client secret and access token appear in neither stdout nor stderr.
- Temp dirs removed and mock server closed in `after`.

Limitation: the mock only answers one valid `initialize` round trip. It does not encode batch or session behaviour.
