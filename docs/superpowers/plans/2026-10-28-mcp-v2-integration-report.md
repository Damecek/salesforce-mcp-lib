# MCP v2 integration verification report

Date: 2026-10-28. Branch `feat/mcp-v2`. Scratch org `mcp-lib-v2-validation` (`00DG500000VIlBWMA1`),
existing, none created. No access token, secret or auth URL appears in this report, in the script, or
in any saved output (the script aborts if its output contains the token).

## Verdict

- Live proof is real for the packed npm **bridge and stdio listener** talking to the real Apex
  endpoints. It is not an OAuth proof: no External Client App credentials exist for the scratch org.
- 108 live checks, 0 failed, on three endpoints (`minimal` 29, `harness` 40, `e2e` 39).
- **One real Apex bug found** (case-insensitive header and method matching, section 5). Official
  conformance reports one more behaviour mismatch (modern `initialize`), which follows the design.
- Full conformance is **not** claimed. Five official scenarios pass fully; the other six fail or cannot run, for the
  reasons in section 4.

## 1. What was exercised and how

Auth distinction, stated plainly:

| Flow | Result |
| --- | --- |
| Real OAuth (client credentials or authorization code) against the org | **Not run.** The CLI has no static-token mode, and creating an ECA only for this was out of scope. |
| Installed CLI (`npm pack` tarball, `npm install`) against a mock Salesforce | Already proven by `tests/npmConsumer.smoke.test.ts` (mock OAuth, one `initialize` round trip). Not repeated here. |
| `createBridge` and `startStdioListener` from the **installed tarball** with a one-method auth adapter, against the **real** Apex endpoints | **Run** (this report). The adapter returns the scratch org session token held in process memory only. It cannot refresh. 401 re-auth and OAuth refresh were therefore not exercised live. |

The token comes from the sf CLI's own `@salesforce/core` (`AuthInfo`/`Connection`). `sf org display`
now redacts the token, so it cannot be used for this.

Commands (run from the repo root; `/tmp/mcpv2-int` is outside the repo and holds the temp artifacts):

```bash
# build, pack and install the artifact under test (package version in the tarball: 2.0.0)
cd packages/salesforce-mcp-lib && npm run build
npm pack --pack-destination /tmp/mcpv2-int/pack            # salesforce-mcp-lib-2.0.0.tgz, 66 files, 62.6 KB
cd /tmp/mcpv2-int/consumer && npm install /tmp/mcpv2-int/pack/salesforce-mcp-lib-2.0.0.tgz --omit=dev

# pinned official schemas (commit 271ecc9accafdd9b83a3c869fa67c22953b2af80, the commit the design pins)
curl .../271ecc9.../schema/2026-07-28/schema.json  and  .../schema/2025-11-25/schema.json   # 200 OK each

# test-only tooling in a temp dir, never in the repo
cd /tmp/mcpv2-int/tools && npm install ajv ajv-formats @modelcontextprotocol/conformance@alpha --ignore-scripts

# the live run
node scripts/verify-mcp-v2.mjs --org mcp-lib-v2-validation \
  --package-dir /tmp/mcpv2-int/consumer/node_modules/salesforce-mcp-lib \
  --tools-dir /tmp/mcpv2-int/tools --schema-dir /tmp/mcpv2-int/schema
# exit 0, "108 checks, 0 failed"
```

`scripts/verify-mcp-v2.mjs` is new and reusable. It writes nothing to disk, adds no dependency (ajv is
loaded from `--tools-dir`), and makes read-only calls only. Salesforce writes: none. The one org call
besides the MCP endpoints is `GET /services/data/` to refresh the session. The `harness` and `e2e`
endpoints ran `tools/call`, `resources/read` and `prompts/get`. The only data touched is a read-only
`query_accounts` (`WITH USER_MODE`) that returned one account row.

## 2. Covered flows (all PASS)

Per endpoint (`minimal`, `harness`, `e2e`), through the packed bridge:

- Modern `server/discover`, `tools/list`, `resources/list`, `resources/templates/list`, `prompts/list`.
  An unadvertised list (`minimal` has no resources or prompts) returns `-32601`.
- Modern `tools/call` of a safe echo (`minimal_echo`, `dev_echo`) or the read-only query (`query_accounts`),
  and a bad-arguments call (tool error or protocol error, no crash).
- `harness`: `resources/read` of `dev://harness/status`, `prompts/get`, `completion/complete`
  (`values: []`). `e2e`: `resources/read` of `salesforce://org/info`, `prompts/get`, `completion/complete`,
  templates list. Unknown URI returns `-32602` with `data.uri`.
- Notification `notifications/initialized`: HTTP 202, bridge writes nothing (modern and legacy).
- Legacy: `initialize` (`protocolVersion` 2025-11-25, no `resultType`/`ttlMs`/`cacheScope`), then
  `tools/list` and `tools/call`.
- Errors: unknown method modern and legacy (`-32601`), unsupported protocol version (error from Apex),
  invalid `_meta` version rejected by the bridge locally (`-32600`, no Salesforce call).
- Raw HTTP probes the bridge cannot produce: modern body without headers (400, `-32020`), missing
  `Mcp-Method` (400, `-32020`), `Mcp-Method` differing from the body (400, `-32020`, body matches
  `HeaderMismatchError`), foreign `Origin` (403, `-32600`), malformed JSON (`-32700`).
- Real `startStdioListener` (from the tarball) with the bridge over `harness`: modern discover, a
  notification and a legacy `initialize` produce exactly two output lines.

Schema validation (ajv 2020-12, test-only) against the pinned 2026-07-28 schema: `DiscoverResultResponse`,
`ListToolsResultResponse`, `ListResourcesResultResponse`, `ListResourceTemplatesResultResponse`,
`ListPromptsResultResponse`, `CallToolResultResponse`, `ReadResourceResultResponse`,
`GetPromptResultResponse`, `CompleteResultResponse`, `JSONRPCErrorResponse`, `HeaderMismatchError`.
Legacy results against the 2025-11-25 schema: `InitializeResult`, `ListToolsResult`, `CallToolResult`.
Every validation passed.

## 3. Not covered

- Real OAuth against the scratch org (client credentials, authorization code, refresh) and live
  401 re-authentication.
- Concurrency, cancellation, oversize bodies (413) and timeouts against the live org (unit tests only).
- `resources/templates/read` of a template URI, templates completion, pagination cursors and
  `ttlMs` expiry behaviour over the live endpoint.
- Multi-user `with sharing` behaviour (one session user only).
- Windows and non-macOS runs.

## 4. Official conformance (`@modelcontextprotocol/conformance@0.2.0-alpha.12`)

The tool only takes a URL. A throwaway loopback shim (`/tmp/mcpv2-int/shim.mjs`, 127.0.0.1:18911,
stopped afterwards) added the in-memory session token and forwarded to `/services/apexrest/mcp/harness`.
The shim does not forward `Host`, so Apex never sees the tool's Host header. This is Apex directly, not
the bridge.

Command per scenario: `conformance server --url http://127.0.0.1:18911/ --scenario <name> --spec-version 2026-07-28 --timeout 30000`

| Scenario | Result | Reason |
| --- | --- | --- |
| `caching` | PASS 8/8 | |
| `tools-list` | PASS 3/3 | |
| `resources-list` | PASS 2/2 | |
| `prompts-list` | PASS 2/2 | |
| `sep-2164-resource-not-found` | PASS 4/4 | |
| `server-stateless` | 20/25 | 4 "not testable": they need the fixture tools `test_missing_capability` (2 checks), `test_streaming_elicitation` and `test_logging_tool`, which the harness lacks. 1 real mismatch, the `initialize` case below. |
| `http-header-validation` | 12/13 | **Real bug**, section 5. |
| `http-custom-header-server-validation` | 1/6 | Not testable: needs a tool with `x-mcp-header` annotations. Not supported by the library. |
| `dns-rebinding-protection` | 1/2 | The valid-localhost case gets 403 because Apex rejects every `Origin` not in `allowOrigin` (default: none). Per design (spec 6.1 step 2). Not a defect. |
| `completion-complete` | 1/2 | Fixture prompt `test_prompt` absent. Not testable. |
| `tools-call-simple-text` | 1/2 | Fixture tool `test_simple_text` absent. Not testable. |

Modern `initialize` mismatch: the tool sends `initialize` with modern headers and expects 404
`-32601`. The library answers it as legacy `initialize` with 200, because the design keeps one endpoint
serving both eras (design 6.1 step 8, "initialize is legacy"). This is a design decision to confirm, not
a plain bug. If strict modern behaviour is wanted, a modern-headered `initialize` should return 404.

The remaining conformance scenarios (input-required results, SSE streams, sampling, elicitation) need
fixtures or transports this library does not provide and were not run.

> **Update (same day):** sections 4 and 5 describe the state before the Apex fix wave. Both items below
> are fixed and re-verified live; see `2026-10-28-mcp-v2-apex-fixes.md` (case-sensitive comparisons, and
> `initialize` with an explicit modern version now gives 404 `-32601`).

## 5. Defect found (not fixed: production source was out of scope)

**Case-insensitive string comparison in header and method validation.** Apex `==` and `!=` on
`String` ignore case. Live evidence on `harness` through the shim:

| Request | Expected | Actual |
| --- | --- | --- |
| `Mcp-Method: TOOLS/LIST`, body `tools/list` | 400 `-32020` | 200 |
| `Mcp-Name: DEV_ECHO`, body `params.name` `dev_echo` | 400 `-32020` | 200 |
| header and body both `Tools/List` | 404 `-32601` | 200 (result returned) |

Spec: header values are case-sensitive (conformance check `ServerRejectsCaseMismatchValue`).
Locations: `force-app/main/mcp/classes/McpRuntime.cls:220` (`mcpMethod != method`), `:231`
(`decodeHeaderValue(...) != (String) value`), and the method dispatch comparisons (`method == '...'`,
lines 192, 223, 249, 250). Fix: use `.equals()` for these comparisons. Line 200 (`metaVersion != headerVersion`) is lower risk (versions are
digits and dashes) but should use `.equals` too. Add Apex tests with a differently-cased header and a
differently-cased body method.

## 6. Dev Hub recheck (read-only, no login prompt, nothing created)

`sf org list --all` and `sf package list --target-dev-hub mcp-lib-devhub`:

| Item | Value |
| --- | --- |
| Alias `mcp-lib-devhub` | present, `Connected` |
| Org id | `00DdL00000q1WdDUAU`, Dev Hub enabled, not a sandbox |
| Instance | `orgfarm-c4897d7670-dev-ed.…` (Developer Edition) |
| User | `ste…@agentforce.com` (masked) |
| Package `SalesforceMcpLib` | `0HodL0000002PQXSA2`, Unlocked, no namespace. Matches `sfdx-project.json` `packageAliases`. |
| Existing versions | 11. Latest listed: `2.0.0.1` (`04tdL000000REenQAG`). |

Notes for the release:

- The Dev Hub already holds a version **`2.0.0.1`**. It is not in `sfdx-project.json` `packageAliases`
  (last alias `SalesforceMcpLib@1.2.0-1`), and this task created nothing. Check whether it came from an
  earlier attempt. The next `2.0.0.NEXT` run produces `2.0.0.2`.
- `sfdx-project.json` is modified (`versionNumber` `1.2.0.NEXT` to `2.0.0.NEXT`) by someone else's work.
  Left as found.
- No package version was created, no `--skip-validation`, no default or config changed
  (`target-org` and `target-dev-hub` stay unset).

## 7. Cleanup and state

- Loopback shim killed and port 18911 confirmed free.
- Repo changes by this task: `scripts/verify-mcp-v2.mjs` (new) and this report. `packages/salesforce-mcp-lib/dist/`
  was rebuilt (ignored build output). No other source, test or metadata file touched. Nothing committed or pushed.
- `/tmp/mcpv2-int` (tarball, schemas, tooling, conformance output) is left for inspection. It holds no secrets
  (the conformance output records request and response bodies only, never the Authorization header).
