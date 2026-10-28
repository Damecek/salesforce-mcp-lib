# Chunk C report: docs, package metadata, CI, release scripts

Date: 2026-10-28. Branch `feat/mcp-v2`. No commits, tags, pushes, publishes, package versions or org writes.
No Apex, TypeScript source or test file was edited. No Salesforce org was contacted.

## Result

2.0.0 is documented as **unreleased** everywhere. There is no fake `04t` install URL: the root README gives a
source-install path (`sf project deploy start --source-dir force-app`) and says the package install section
gets its id after the version is created. The npm package is `2.0.0` locally, run from a checkout until published.

## Files changed

| File | Change |
| --- | --- |
| `README.md` | rewritten (sections below) |
| `packages/salesforce-mcp-lib/README.md` | updated (sections below) |
| `CLAUDE.md` | structure block, recent changes, release rules, unreleased and no-fake-URL rule |
| `docs/architecture.md` | JSON-RPC layer replaced by the runtime pipeline; proxy role, headers, wire format reference |
| `docs/mcp-wire-contract-2026-07-28.md` | new: date, revision, full source links, C2 and C3 tables, known gaps |
| `docs/mcp-wire-contract-audit-2025-11-25.md` | marked superseded |
| `docs/superpowers/specs/2026-10-28-mcp-v2-design.md` | C3 sections 7.1, 7.3, 7.4 and 7.2 updated (below) |
| `sfdx-project.json` | `versionNumber` `2.0.0.NEXT`; package id and every alias unchanged, no new alias |
| `config/package-version-def.json` | `2.0.0.NEXT`, name and description; removed `ancestorVersion` (managed packages only, design 2.6) |
| `packages/salesforce-mcp-lib/package.json`, `package-lock.json` | version `2.0.0` (`npm version 2.0.0 --no-git-tag-version`) |
| `scripts/release-create.sh` | requires `--target-dev-hub` or `SF_DEVHUB`, usage error otherwise; `--target-org` kept as a deprecated alias with a warning; `--code-coverage` kept |
| `scripts/release-promote.sh` | takes the explicit hub (`--target-dev-hub` or `SF_DEVHUB`) and passes it on |
| `scripts/org-create.sh`, `org-delete.sh` | no hardcoded hub; `org-create.sh` needs `--target-dev-hub` or `SF_DEVHUB` |
| `scripts/org-test.sh` | `--synchronous` (one class only) replaced by `--test-level RunLocalTests`, `--wait 20` |
| `.github/workflows/ci.yml` | new: push and pull_request, Node 20 and 22, `npm ci`, `npm test`, `npm run lint`, `npm run build`, no secrets, no Salesforce step |
| `.claude/skills/release/SKILL.md` | explicit hub question, new script usage, 2.0.0 notes, unverified-install step |
| `examples/minimal/README.md`, `examples/e2e-http-endpoint/README.md` | 2.0.0 API, source deploy, checkout proxy, template listed |
| `specs/001-apex-mcp-server/quickstart.md` | one-line "historical 1.x" banner |

## README sections

Root `README.md` (all changed): release-status box; supported protocol versions and compliance (no full
compliance claim, per-tool rate-limit gap); feature matrix, both eras, reasons tied to governor limits;
HTTP auth discovery (JSON-only) caveat; How it works; Security (user mode and `with sharing` required for layers 2 to 4);
Quick start 1 to 4 (source install, minimal endpoint and tool copied from the example sources, ECA, client config,
checkout proxy until publish); Apex API walkthrough (server, tools, resources and templates, prompts, completions,
rich content, schema subset, developer responsibilities, governor limits and size guards); Migrating from 1.x (class
table, behaviour changes, upgrade caveats); CLI reference (new flags, https rule, proxy limits, HTTP status table);
Tech stack; Project structure; Contributing (CI scope, manual Apex validation, release).

npm `README.md`: release-status box; What it does; Supported protocol versions (new); CLI table (two new flags, https
rule); Behaviour and limits (new: concurrency, queue, 64 MiB budget, 8 MiB response cap, lossless numbers, timeouts,
cancellation, errors, shutdown, zero deps, Node 20+); Prerequisites (2.x Apex required); How it works (proxy reads
framing only); HTTP authentication discovery (new). Shared facts (flags, ranges, limits, eras, gaps) match the root
README and `--help` output. Em dashes in the touched headings were replaced.

## Design C3 edits

Section 7.1: duplicate request id is written without `id`; client-response rule needs `id` plus `result` or `error`;
other objects without `method` and non-string, non-safe-integer ids are `-32600`. Section 7.2: malformed modern
`_meta` version is `-32600` locally, never legacy; method over 256 and `Mcp-Name` source over 2048 chars rejected.
Section 7.3: `JSON.stringify(JSON.parse(body))` replaced by lossless whitespace compaction, envelope rules,
id injection, shared 401 re-authentication. Section 7.4: one request deadline over auth, retry and response, 64 MiB
byte budget, 30 s OAuth deadline (separate from the request timeout), https policy. Header errors `-32020` and the
`256 KiB` defaults were already in section 6 and 11 and are mirrored in the docs.

## Checks run

| Check | Result |
| --- | --- |
| `bash -n scripts/*.sh` | all pass |
| `release-create.sh`, `release-promote.sh`, `org-create.sh` with no hub | exit 1 with usage; `--help` exits 0 |
| README flags vs `node dist/index.js --help` | every flag present in both READMEs, ranges and defaults match |
| Relative links in README, architecture, wire contract, example READMEs | none broken |
| `npm pack --dry-run` | `salesforce-mcp-lib-2.0.0.tgz`, no `dependencies` in `package.json` |
| `npm run lint` | clean |
| `npm consumer smoke test` (packs, installs, runs the bin) | 3 of 3 pass with version 2.0.0 |
| CI YAML | parses; matrix `[20, 22]` |
| Full `npm test`, Apex tests | not re-run (docs-only chunk). Last known: 331 npm tests, 188 Apex tests at 97% org-wide (final release evidence; 154 was an earlier baseline) |

## Unproven or not done

- No package version exists. Install and upgrade of the unlocked package 2.0.0, including class deletion and the
  `McpServer` name reuse over 1.x, is unproven. The README says existing 1.x endpoints will not compile against 2.0.0
  and promises nothing about survival.
- The owning Dev Hub was not contacted and its username is not in any public file. Last check it was not
  authenticated locally. Hub-dependent steps (create, promote) were not run. `release-create.sh` and the skill read the
  hub from `--target-dev-hub` or `SF_DEVHUB`.
- Apex code samples in the README that are not copied from `examples/` (completion, rich content, server options) were
  written against the public signatures in the source and were not compiled or deployed.
- CI was not run on GitHub. Apex validation is documented separately (README Contributing) and is manual.
- Pre-delivery OCR review skipped: documentation, metadata and shell-usage changes only, and the task said no subagents.
- `mcp-lib-devhub` remains in no file. `specs/001` and `specs/003` still describe 1.x and per-user setup in the old
  wording beyond the one banner; only the banner was added.

## Next (parent)

1. Review the READMEs and run the scratch-org validation again (chunk A commands).
2. With your go, create the package version from the owning hub, record the `04t` alias, then replace the root README
   source-install-only note with the `04t` id and try install and upgrade in a sandbox.
