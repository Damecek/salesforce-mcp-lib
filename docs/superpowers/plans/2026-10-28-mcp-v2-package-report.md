# MCP v2 package build and install report (2026-10-28)

Status: beta package built and verified in scratch orgs. Not promoted, npm not published, nothing committed, tagged or pushed.

## Package

| Item | Value |
| --- | --- |
| Package | SalesforceMcpLib, `0HodL0000002PQXSA2` (Unlocked) |
| Dev Hub | `mcp-lib-devhub`, org `00DdL00000q1WdDUAU` |
| Create request (08c) | `08cdL000000C3YPQA0`, Success |
| Package2 version (05i) | `05idL0000004rFRQAY` |
| Subscriber version (04t) | `04tdL000000qXzBQAU` |
| Version | 2.0.0.1 (build 1), branch `feat/mcp-v2`, Released = false |
| Coverage | 99% package, `HasPassedCodeCoverageCheck` true, validation not skipped |
| Alias added to `sfdx-project.json` | `SalesforceMcpLib@2.0.0-1-feat/mcp-v2` |
| Built from | HEAD `66574f9` plus the uncommitted worktree |
| Source manifest | `2026-10-28-mcp-v2-package-source-manifest.sha256` (67 files). SHA256 of the manifest: `78a1909c354f08ec6dcb8e5cd2b134447bb14743c649254e020de0058e16b537` |

The unrelated March beta `04tdL000000REenQAG` (2.0.0.1) was not touched. The create ran once, with the flags of `scripts/release-create.sh` plus `--branch` and `--version-description` (the script has neither flag). One of the 6 daily creates is used.

## Pre-build validation (`mcp-lib-v2-validation`)

- Deploy of `force-app` including the `McpWire.scalarBytes` patch succeeded. The getters are legal at API 65.
- RunLocalTests: 188 passed, 0 failed, org-wide coverage 97%. Includes `McpWireTest.compoundAddressAndLocationAreBounded`.
- npm: build, `tsc --noEmit` lint and 331 tests all pass (version 2.0.0).
- Patch review: Address is counted before Location (Address extends Location), 256 plus 6 per character of 8 text getters, Location flat 128. No change made.

## Fresh install (`mcp-lib-v2-install`, scratch org `00DG500000VJMB3`, via `carvago-prod`, 3 days, expires 2026-10-31)

- `sf package install 04tdL000000qXzBQAU` succeeded before any source deploy.
- InstalledSubscriberPackage `0A3G5000002lMFGKA2`: SalesforceMcpLib 2.0.0.1.
- Consumers only (examples/minimal, examples/e2e-http-endpoint, dev/mcp-harness): 13 components deployed, 0 errors. They compile against the installed public API. `E2eHttpEndpointTest`: 3 of 3 passed.
- `scripts/verify-mcp-v2.mjs` (packed npm 2.0.0 bridge to the live Apex endpoints, both protocol eras, large payload and case guards): 144 checks, 0 failed. Output is in `/tmp/live-install.txt`, no tokens printed. It is not an OAuth test, auth is the sf session.

## Upgrade (`mcp-lib-v2-upgrade`, scratch org `00DAW00000VRd8Q`, expires 2026-10-31)

Installed released 1.2.0.1 (`04tdL000000Ut0fQAC`), then the 2.0.0.1 beta with `--upgrade-type Mixed`. Both succeeded and InstalledSubscriberPackage reports 2.0.0.1. No 1.x consumer endpoint classes existed, so subscriber references to removed classes remain untested.

## Limitations

- Beta (Released = false): installs only in scratch orgs and sandboxes.
- No OAuth or External Client App run, no per-tool rate limiting, no SSE, tasks, MRTR, subscriptions or logging.
- The package's own Apex tests ran in the validation org and in the package build, not in the install org.

## README

The root README now states the beta status and gives the beta install command. No production URL. `packages/salesforce-mcp-lib/README.md` has no install claim and is unchanged.

## Remaining irreversible actions (need the user's go)

1. Review and commit the version files, the `sfdx-project.json` alias, the README and the docs.
2. Promote: `./scripts/release-promote.sh 04tdL000000qXzBQAU --target-dev-hub mcp-lib-devhub`.
3. Tag `v2.0.0-sf2.0.0-1`, merge `feat/mcp-v2` to `main`, `npm publish`, push.
4. Optionally delete the two scratch orgs after review.
