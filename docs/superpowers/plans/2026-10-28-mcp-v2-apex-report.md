# Chunk A report: Apex core for salesforce-mcp-lib v2

Date: 2026-10-28. Branch: `feat/mcp-v2` (created from `main` at `66574f9`, plus the untracked plan,
design and smoke-test files carried along). No commits, no push, no worktree, no checkout of any other
branch. Scratch org: `mcp-lib-v2-validation` (`00DG500000VIlBWMA1`, expires 2026-10-31). No other org
and no Dev Hub was touched. No package version was created.

Result: 154 Apex tests, 100% passing, in two consecutive full runs. Org-wide coverage 97%. Every
class with executable lines is at 97% or higher. Live endpoints on the scratch org answered modern
`server/discover` and legacy `initialize`.

## 1. Spike S0 (sanitized evidence)

Probe: throwaway `@RestResource(urlMapping='/mcpprobe')` class deployed from `/tmp/s0probe` (outside
the repo, never committed; deploy id `0AfG500000TFcViKAL`). It echoed header key names, the values of
a fixed allowlist of non-secret headers (`mcp-*`, `origin`, `accept`, `content-type`), heap and CPU
limits, and returned a status taken from a query parameter. Requests went through
`sf api request rest`, so the access token stayed inside the CLI and was never printed or logged.
`Authorization`, cookies and the other headers were never echoed.

| Question | Observed |
| --- | --- |
| Custom MCP headers reach `RestRequest.headers` | Yes. Keys arrived lower-cased: `mcp-protocol-version`, `mcp-method`, `mcp-name`. Standard headers kept their sent casing (`Origin`, `Content-Type`, `Accept`). Value of `Mcp-Name: =?base64?SGVsbG8=?=` arrived intact. |
| Mixed `Accept: application/json, text/event-stream` | No 406. HTTP 200. |
| 202 with empty body | HTTP 202, no body. |
| 400, 404, 413, 405 with an Apex-set JSON body | Status codes and JSON bodies preserved. `Allow: POST` on 405 preserved. `Content-Type: application/json` preserved. |
| Heap limit at runtime | `Limits.getLimitHeapSize()` = 10,000,000 (synchronous). CPU limit 10,000 ms. |
| `JSON.deserializeUntyped` number types | `1` Integer, `3000000000` Long, `9223372036854775807` Long, `1.5` and `1.0` and `1e2` Decimal. `9223372036854775808` and `123456789012345678901` throw `JSONException`. `1e400` parses as Decimal `1E+400`. |

Consequences: header validation is feasible, so work continued. The lower-casing map is mandatory
(the casing is mixed). Out-of-range integers become `-32700`. Decimal ids need a range check.

Cleanup: `sf project delete source --metadata ApexClass:McpProbeS0` deleted the probe. A follow-up
POST to `/services/apexrest/mcpprobe` returned `NOT_FOUND`.

## 2. Design edits recorded (parent corrections)

All in `docs/superpowers/specs/2026-10-28-mcp-v2-design.md`:

- Section 2 item 1, 6.8: default `maxRequestBytes` and `maxResponseBytes` are 262,144. Setters accept
  1,024 to 6,000,000. The runtime also caps them by remaining heap (request: heap / 8; response:
  estimate x 3 must fit the remaining heap).
- 5.3: raw schema walk is iterative, counts every value including `enum`, `default`, `examples`
  (depth 16, 1,000 nodes, 200 entries per collection), cycles fail the depth limit.
- 6.1 step 10: both `_meta` fields (`protocolVersion`, `clientCapabilities`) are required even when
  the header carries the version. 10a and 10c: a missing `Mcp-Method` or `Mcp-Name` header is
  `-32020` (S-HTTP says "REQUIRED"). New step 4a: bounded walk of the parsed request.
- 6.8: the pre-serialization walk covers the entire result map (`structuredContent`, `_meta`,
  annotations, icons, resource contents), with node, depth and collection limits, before
  `JSON.serialize`. `structured()` text is generated after the check and counted twice. The guards are
  documented as not preventing a handler `LimitException`.
- New section 11 lists the decisions taken during implementation (also in section 5 below).

Frozen items C1 (names and signatures) are unchanged except for two additions: `McpRequest.forResource(uri, variables)` and the
public accessors Apex forces on `McpRuntime`, `McpWire`, `McpToolResult` and friends. Parent sign-off
is not needed for additions; flagged here anyway.

## 3. What was built

Source deletion (blanket removal kept: nothing outside chunk A depended on the old classes; only docs
and old speckit specs mention them): `git rm` was undone with `git reset` on `force-app`, so the
deletions show as unstaged (`D`). Deleted `force-app/main/json-rpc/` (14 classes, 28 files) and all 32 old classes
in `force-app/main/mcp/classes/` (64 files). Some old names were reused by new classes, so git shows
those as modified rather than deleted.

New in `force-app/main/mcp/classes/` (apiVersion 65.0, `inherited sharing`):

- API: `McpServer`, `McpTool`, `McpToolResult`, `McpToolAnnotations`, `McpContent`,
  `McpResourceContents`, `McpAnnotations`, `McpIcon`, `McpSchema`, `McpResource`,
  `McpResourceTemplate`, `McpResourceResult`, `McpPrompt`, `McpPromptResult`, `McpCompletion`,
  `McpRequest`, `McpException`, `McpConfigurationException`.
- Internal: `McpRuntime` (registrations and the 6.1 pipeline), `McpWire` (envelopes, id
  normalisation, header decoding, bounded walk), `McpUriTemplate`, `McpProtocolException`.
- Tests: `McpRuntimeTest`, `McpServerTest`, `McpToolTest`, `McpSchemaTest`, `McpResourceTest`,
  `McpPromptTest`, `McpCompletionTest`, `McpContentTest`, `McpWireTest` (extra), and the shared
  `@IsTest` helper `McpTestKit` (fixtures, request builders).
- Examples rewritten and deployed: `examples/minimal` (endpoint, tool, test), `examples/e2e-http-endpoint`
  (endpoint, query tool, org resource, new account template, prompt, test), `dev/mcp-harness` (endpoint,
  tool, resource, prompt). Every example class is `with sharing`; the query tool, org resource and
  account template use `WITH USER_MODE`.

Not touched: `packages/**`, `README.md`, docs other than the design and this report, `sfdx-project.json`.

## 4. Commands and results

Scratch org, stale classes. The scratch org held 54 old classes. A source deploy does not remove
metadata, so a one-off pre-destructive deploy removed the 49 superseded classes in this scratch only
(the other five old names were overwritten in place):

```
sf project generate manifest --source-dir force-app --name package --output-dir /tmp/mcpv2-destructive
sf project deploy start --manifest /tmp/mcpv2-destructive/package.xml \
  --pre-destructive-changes /tmp/mcpv2-destructive/destructiveChangesPre.xml \
  --target-org mcp-lib-v2-validation --wait 10
```

(`destructiveChangesPre.xml` listed the org's `ApexClass` names that no longer exist in source.)
After it, a SOQL query on `ApexClass` showed only the new library, its tests, and (later) the examples.

Deploys: `sf project deploy start --source-dir force-app --target-org mcp-lib-v2-validation --wait 10`
(library, last id `0AfG500000TFdTNKA1`) and
`--source-dir examples/minimal/force-app --source-dir examples/e2e-http-endpoint/force-app --source-dir dev/mcp-harness/force-app`
(id `0AfG500000TFdRlKAL`).

Full run (command from the plan, `--synchronous` dropped because it allows one class only, and
`RunLocalTests` instead of class names so examples run too):

```
sf apex run test --test-level RunLocalTests --target-org mcp-lib-v2-validation \
  --code-coverage --result-format human --wait 20
```

| Run id | Tests | Pass | Org-wide coverage |
| --- | --- | --- | --- |
| `707G500001ZUjHf` (before the last additions) | 149 | 100% | 99% |
| `707G500001ZTH5H` | 154 | 100% | 97% |
| `707G500001ZUjjO` (final) | 154 | 100% | 97% |

Tests per class: McpRuntimeTest 36, McpToolTest 21, McpResourceTest 19, McpSchemaTest 19,
McpContentTest 17, McpServerTest 14, McpCompletionTest 9, McpPromptTest 9, McpWireTest 6,
E2eHttpEndpointTest 3, MinimalMcpEndpointTest 1.

Coverage of the final run, per class:

| Class | % | Uncovered lines |
| --- | --- | --- |
| McpRuntime, McpServer, McpTool, McpToolResult, McpToolAnnotations, McpContent, McpResourceContents, McpResourceResult, McpResource, McpResourceTemplate, McpPrompt, McpPromptResult, McpCompletion, McpIcon, McpAnnotations, McpSchema, McpUriTemplate, McpProtocolException | 100 | none |
| McpRequest | 99 | 92 (`catch` in `getLong` after a `Decimal` operation throws, not reachable with real `Decimal` input) |
| McpWire | 97 | 48, 49 (generic `catch` after base64 decoding passed the shape and round-trip checks), 69 (the same defensive `catch` in `normalizeId`) |
| McpException, McpConfigurationException | 0% shown | The classes have no executable lines, so Salesforce reports 0 of 0 |
| Example classes (7) | 100 | none |

The harness classes (`DevMcpHarness*`) have no tests by design (development-only).

Live proof on the scratch org (through `sf api request rest`, headers as in the contract):

- `POST /services/apexrest/mcp/e2e`, `/mcp/minimal` and `/mcp/harness`: modern `server/discover`
  (headers `MCP-Protocol-Version: 2026-07-28`, `Mcp-Method: server/discover`) returned HTTP 200 with
  `resultType: "complete"`, `ttlMs: 0`, `cacheScope: "private"`, `supportedVersions`, capabilities and
  `_meta["io.modelcontextprotocol/serverInfo"]`.
- Legacy `initialize` (no extra headers) returned HTTP 200 with `protocolVersion: "2025-11-25"`, no
  `resultType`, `ttlMs`, `cacheScope`.
- Notification returned 202 empty. Unknown modern method returned HTTP 404 with `-32601` and the
  `id` `9007199254740991` echoed exactly. Missing version header returned 400 `-32020`. A 300 KB body
  returned 413. `tools/call query_accounts` ran in user mode and returned `structuredContent` plus the
  text copy.

Governor evidence (tests, generous bounds, no microbenchmarks):

- `McpRuntimeTest.frameworkUsesNoSoqlDmlOrCalloutsAndStaysCheap`: after discover, tools/list,
  tools/call, resources/read, prompts/get and a legacy call: `Limits.getQueries()`,
  `getDmlStatements()`, `getCallouts()`, future and queueable counts are all 0. CPU under 3,000 ms and
  heap growth under 500,000 bytes for the whole sequence.
- `representativeLargeResultStaysWithinBudget`: 300 rows x 8 fields (about 2,700 nodes, 2 copies)
  returns 200 with zero SOQL, DML and callouts, CPU under 3,000 ms, heap growth under 1.5 MB.
- `largeRegistryListingStaysBounded`: 100 tools in one page, CPU under 3,000 ms.
- `matcherIsLinearOnAdversarialInput`: URI template matching against 2,000-character hostile input
  stays under 1,000 ms.
- `McpContentTest.hugeTextIsRejectedBeforeSerialization` measures heap before and after: a 300,000
  character text block is refused with growth under 150,000 bytes, while
  `aRaisedLimitLetsTheSameTextThrough` shows the success path adds over 250,000 bytes. That separates
  "rejected before serialization" from "rejected after".
- One measurement for the record (anonymous Apex, includes log overhead): the bounded walk costs
  about 0.7 s CPU for 45,000 nodes, roughly the cost of `JSON.serialize` of the same data;
  `JSON.deserializeUntyped` of 110 KB cost about 2.4 s there. That is why the node budget is
  `nodeLimit(bytes) = min(200,000, max(25,000, bytes / 8))` (32,768 at the default limit) and not a
  fixed number.

Real bugs the tests caught and I fixed: the 10-error cap in `McpSchema` was not enforced in the
required-property, closed-object and unknown-property loops; a template without variables matched
longer URIs; plus compile-time reserved words (`end`, `where`, `Page`, `list`, `blob`).

## 5. API deviations, ambiguities resolved, limitations

Resolved ambiguities (all also in design section 11):

1. `ref/resource` completion uses the field `uri`, as S-SCHEMA defines it. Static resource ref gives
   empty values. Unknown refs and undeclared arguments give `-32602`.
2. `Mcp-Method` and `Mcp-Name` absent on a modern request is `-32020` (S-HTTP: REQUIRED).
3. Out-of-range JSON integers are `-32700` (the platform parser throws). `1e400` as an id is `-32600`.
4. `structured(null)` and `structuredContent(null)` mean no structured content. A builder
   `output(...)` with a successful result lacking `structuredContent` is `-32603`.
5. Template variables match lazily; invalid percent-encoding is "no match"; `+` stays a plus
   (`urlDecode` is called on the value after `+` is replaced by `%2B`).
6. Modern `_meta.protocolVersion` of the wrong type counts as missing. The header never substitutes
   for it. A legacy header with a non-string `_meta` version is served as legacy and the junk ignored.
7. Legacy `initialize` params are not validated (lenient, for client compatibility). **Superseded**:
   `initialize` is legacy only when no version is named (fixes report).
8. Registration order is the list order everywhere (tools, resources, templates, prompts).

API additions versus spec 5.1: `McpRequest.forResource(String, Map<String,String>)`,
`McpRequest.variables()`, `McpSchema.kindName()`, `McpSchema.checkRaw(...)` and other `public`
members that Apex forces on internal collaborators (`McpTool.compile()`, `toWire(...)`,
`McpToolResult.contentBlocks()` and similar). They are not part of the supported API.

Limitations (honest list):

- Guards reduce, they do not remove, the chance of a `LimitException`. Handler code (SOQL, DML,
  loops) is not bounded, and an uncatchable `LimitException` yields a platform error body.
- **Superseded** by `2026-10-28-mcp-v2-apex-fixes.md`: an `SObject` is now sized by its populated fields and
  `Set`, non-`String`-key `Map` and custom objects are refused before serialization.
- `structured()` doubles the counted size, so a structured result over about half the response limit
  is refused by design. Raise `maxResponseBytes` for such tools.
- Result size over the default 256 KiB is refused with `-32603` "Response exceeds the server size
  limit". CPU: parsing a 256 KiB request body can consume several seconds of the 10 s CPU limit on
  its own (platform parser cost); the default limits keep this bounded.
- Output validation and tool-argument validation implement the documented subset only; `pattern`,
  composition and `$ref` are not offered by the builder and raw schemas are trusted.
- Per-tool rate limiting is not implemented (spec 3.2).
- The scratch org shows a 10 MB synchronous heap; the runtime reads limits at run time and does not
  assume it. Behaviour on a 6 MB org is covered by the formula, not run.

## 6. Not proven, not done

- No package version was created and no installation of a packaged `SalesforceMcpLib` was done. All
  evidence is from source deploys to the scratch org. Nothing here proves the 2GP upgrade path or the
  removal of superseded classes in a subscriber org.
- The npm proxy (chunk B) was not run against these endpoints. The raw HTTP behaviour was exercised
  through `sf api request rest` only.
- The pre-delivery OCR review from the global instructions was skipped, because the task brief for
  this chunk says "No subagents". The parent should run it with the security and protocol scope.
- The MCP Inspector scripts (`examples/e2e-http-endpoint/run-inspector.sh`, `dev/mcp-harness/inspector`)
  were not run.
- `examples/*/README.md` and `dev/**/README.md` still describe the old API (chunk C owns them).

## 7. Notes for the parent and the npm agent

- A legacy request without `MCP-Protocol-Version` gets `400 -32020`. The proxy must send the header
  after `initialize` (it does in C3 7.2).
- HTTP statuses are real: modern protocol errors are 400/404, handler errors are 200, notifications
  202 with an empty body, oversize 413.
- Default size limits are 256 KiB each way. A large tool result is a `-32603` size error, not a
  truncation. The proxy's 8 MiB response cap is unrelated.
- The superseded-class cleanup procedure above applies to every org that already holds 1.x classes
  and is the same concern as design section 9 (upgrade type).

## 8. Current state

- Branch: `feat/mcp-v2`. `git status` shows chunk A changes (deleted old classes, new classes and
  tests, rewritten examples and harness) plus the other agents' files; nothing staged, nothing
  committed. HEAD is `66574f9`.
- Scratch org holds: library classes, tests, examples, harness. Probe removed.
- Temporary helper scripts live in `/tmp` (`deploy.sh`, `runtests.sh`, `s0run.sh`, `s0out/`), outside
  the repository.
