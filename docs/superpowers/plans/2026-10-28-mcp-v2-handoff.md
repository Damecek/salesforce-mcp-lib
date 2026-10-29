# MCP v2 handoff (2026-10-28)

Status: SF package 2.0.0.1 promoted and released; code committed and merged to `main`. npm 2.0.0 is published and the git tag `v2.0.0-sf2.0.0-1` is created (see the release report).
This report does not claim full MCP protocol compliance (no per-tool rate limiting, see Known gaps).

## Package IDs

| Item | Value |
| --- | --- |
| Package | SalesforceMcpLib `0HodL0000002PQXSA2` (Unlocked) |
| Create request (08c) | `08cdL000000C3YPQA0` |
| Package2 version (05i) | `05idL0000004rFRQAY` |
| Subscriber version (04t, authoritative) | `04tdL000000qXzBQAU` |
| Version | 2.0.0.1, branch `feat/mcp-v2`, Released = true (promoted 2026-10-28) |
| Alias in `sfdx-project.json` | `SalesforceMcpLib@2.0.0-1-feat/mcp-v2` (the branch suffix is how the tool named it, not renamed; the 04t is the source of truth) |
| Dev Hub | `mcp-lib-devhub` |

## Evidence

Details in [package report](2026-10-28-mcp-v2-package-report.md).

- Package coverage 99%, `HasPassedCodeCoverageCheck` true, validation not skipped.
- Apex: 188 tests passed, 97% org-wide ([apex fixes](2026-10-28-mcp-v2-apex-fixes.md), [apex report](2026-10-28-mcp-v2-apex-report.md); its 154 figure is the earlier baseline).
- npm: 331 tests passed, build and lint clean ([proxy report](2026-10-28-mcp-v2-proxy-report.md), [npm consumer smoke](2026-10-28-npm-consumer-smoke.md)).
- Fresh install of the 04t in a scratch org: 13 consumer components deployed, `E2eHttpEndpointTest` 3 of 3, 144 live checks passed.
- Upgrade 1.2.0.1 to 2.0.0.1 (`--upgrade-type Mixed`) succeeded. No 1.x consumer classes existed, so references to removed classes are untested.
- Reviews: OCR security and governor findings were handled earlier by the parent. No new review for this docs and artifact step.

## Source manifest check

`2026-10-28-mcp-v2-package-source-manifest.sha256` (manifest SHA256 `78a1909c354f08ec6dcb8e5cd2b134447bb14743c649254e020de0058e16b537`) lists 67 files. 66 match the current tree. The one mismatch is `sfdx-project.json`: the alias line was added after the package was created. With that line removed the hash equals the manifest entry (`4baf2107...`). No packaged Apex source changed after creation.

## npm tarball

- Path: `/Users/adam.stepanek/Downloads/salesforce-mcp-lib-v2/salesforce-mcp-lib-2.0.0.tgz`
- SHA256: `2ac75e004d24ca6f2352216319d02b52395099ca58702c5a20e69feb122f1aa9`
- Built by `npm pack` (prepack runs the build). 66 files, 65.7 kB packed, 269.1 kB unpacked. Runtime dependencies: 0. No env, token or secret files inside.
- Lives in /tmp, so it does not survive a reboot. Copy it somewhere durable if needed, then re-verify the hash.
- Full suites were not rerun, since the source is the same one that passed.

## README changes in this step

- `packages/salesforce-mcp-lib/README.md`: the banner now says `npx salesforce-mcp-lib` currently fetches a 1.x release that does not work with the 2.x Apex framework. It tells users to run the local build or tarball (`node /path/to/dist/index.js`) until 2.0.0 is published, and marks the `npx` form as valid only after publication. The old line saying no Salesforce 2.0.0 package exists was stale and is replaced by the beta status. It also notes that raw `inputSchema(Map)` is not validated against arguments.
- Root `README.md`: already marks 2.0.0 as unreleased, shows the beta as scratch org or sandbox only, and carries the 188 and 331 counts, the top-level `null` structured-content caveat and the local `node` path instead of `npx`. No change needed.
- `2026-10-28-mcp-v2-docs-report.md`: the "154 Apex tests" figure now reads 188.
- The npm README does not claim "any JSON" results, so no `null` caveat was added there.

## Known gaps

- No per-tool rate limiting (the spec says servers MUST rate limit tool invocations).
- No SSE, tasks, MRTR, subscriptions or logging.
- Raw JSON schemas are trusted. The developer must override `validate(McpRequest)`.
- No OAuth or External Client App run in the live checks (auth was the sf session).
- The package's own Apex tests ran in the validation org and package build, not in the install orgs.

## Git state

- Branch `feat/mcp-v2` at `66574f9`, about 205 uncommitted entries (modified, deleted `json-rpc/`, untracked new Apex and TypeScript files).
- `git diff --check`: one finding, a blank line at EOF in `packages/salesforce-mcp-lib/src/oauth.ts:172`. Left unfixed because source edits were out of scope. It is harmless but trivial to fix.
- Untracked names scanned: no `.env`, key, token dump, log or archive files. The only auth-named files are real source (`authHttp.ts`, `authHttp.test.ts`).
- Scratch orgs `mcp-lib-v2-install` and `mcp-lib-v2-upgrade` expire 2026-10-31.

## Remaining steps (each needs explicit user approval)

1. Review and commit (version files, `sfdx-project.json` alias, READMEs, docs). Optionally strip the blank line in `oauth.ts` first.
2. Promote: `./scripts/release-promote.sh 04tdL000000qXzBQAU --target-dev-hub mcp-lib-devhub`.
3. Tag `v2.0.0-sf2.0.0-1`, merge `feat/mcp-v2` to `main`, push.
4. `npm publish` of the 2.0.0 tarball. Only then switch the README `npx` instructions to the published form.
5. Optionally delete the two scratch orgs.

Final parent verification: removed an extra trailing blank line in oauth.ts; git diff --check exits 0. Repacked with prepack build to Downloads. SHA256 remains 2ac75e004d24ca6f2352216319d02b52395099ca58702c5a20e69feb122f1aa9. No packaged Apex source changed.

## Release progress (2026-10-28)

- Promoted `04tdL000000qXzBQAU` (2.0.0.1) via mcp-lib-devhub: `IsReleased` true, coverage 99%.
  Production install URL: https://login.salesforce.com/packaging/installPackage.apexp?p0=04tdL000000qXzBQAU
- Committed on `feat/mcp-v2` and merged to `main` (docs-only changes after promotion; code unchanged since the validated run).
- Published: `salesforce-mcp-lib@2.0.0` on npm, tag `v2.0.0-sf2.0.0-1`. Details in `2026-10-29-mcp-v2-release-report.md`.
