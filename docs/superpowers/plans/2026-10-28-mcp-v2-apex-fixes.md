# Apex review fix wave for salesforce-mcp-lib v2

Date: 2026-10-28. Branch `feat/mcp-v2`. Scratch org `mcp-lib-v2-validation` (`00DG500000VIlBWMA1`) only.
No commit, no push, no package version, no promotion, no TypeScript change, no subagent. Org writes were
limited to source deploys and test runs on that scratch org (deploy ids `0AfG500000TFdrZKAT`,
`0AfG500000TFdunKAD`, and `0AfG500000TFdV0KAL` with `RunLocalTests`).

Result: 187 Apex tests, 100% passing in the final full run (`707G500001ZUkSc`); the three runs before it
(186 tests, `707G500001ZUitZ`, `ZUD1A`, `ZUcr3`) also passed. Org-wide coverage 97%. Baseline was 154 tests. Live script:
144 checks, 0 failed (baseline 108, 36 new). Official conformance `http-header-validation` 14/14 (was
12/13) and `server-stateless` 21/25 (was 20/25); the remaining four need fixture tools this repo does not have.

## 1. Findings and fixes

| # | Finding | Fix | Where |
| --- | --- | --- | --- |
| H1 | A 5 KB body nested 2,500 levels parses, then `instanceof` on the result overflows the stack (uncatchable `LimitException`). A 240 KB body of `[` costs seconds of CPU in the parser. | Lexical nesting check on the raw text before `JSON.deserializeUntyped`: more than `McpWire.WALK_MAX_DEPTH` (32) levels gives 400 `-32600` "Request structure too large". Strings and escapes are handled. The raw text is converted once and reused for the parse. | `McpWire.nestsDeeperThan`, `McpRuntime.process` |
| H2 | Apex `==` and `!=` on `String` ignore case. `Mcp-Method: TOOLS/LIST`, `Mcp-Name: DEV_ECHO` and a body method `Tools/List` were accepted. | `McpWire.same(value, expected)` (exact `equals`) for every comparison the wire contract defines as case-sensitive. A case-sensitive `Set` of known methods is checked first. | see 2 |
| M3 | The output walk counted `Set`, non-`String`-key `Map`, `SObject` and custom objects as a fixed 128 bytes, so `JSON.serialize` later materialized them unbounded. | Fail closed. See 3. | `McpWire.estimateBytes` |
| C | `initialize` was always legacy, even with an explicit modern header (official `server-stateless` mismatch) and with an unknown version. | `initialize` is legacy only when neither the header nor `_meta` names a version. Otherwise normal validation: modern gives the modern checks then 404 `-32601`, unknown gives `-32022`, `2025-11-25` is served as legacy. | `McpRuntime.detectEra` |
| D | The default parameterless tool advertised `additionalProperties: false` but accepted any argument. | `McpTool.compile` keeps the advertised wire shape and validates with a closed empty object; `McpTool.inputValidator()` replaces `inputBuilderSchema()`. | `McpTool`, `McpRuntime.callTool` |
| P | A list page can exceed the response limit. | Documented only: use a smaller `pageSize`. No adaptive paging. | design 6.5, README, `McpServer.pageSize` Javadoc |

Extra small fix: the `requested` version echoed in a `-32022` error is clipped to 128 characters (it was bounded only by the request limit).

## 2. H2: what was compared and how it was audited

Probe on the scratch org (anonymous Apex), for `'TOOLS/LIST'` against `'tools/list'`:

| Operation | Result |
| --- | --- |
| `String == String` | true (case-insensitive) |
| `Object == String`, `Object != String` | case-insensitive |
| `String.equals`, `startsWith`, `List.contains`, `Set.contains`, `Map` keys, `indexOf` | case-sensitive |
| base64 round trip `encode(...) != middle` | case-insensitive (fixed for hygiene; no realistic case-only difference exists) |

Every `==` and `!=` in non-test source was reviewed. Changed to `McpWire.same`: HTTP method, `jsonrpc`,
body method and the `initialize` rule, header and `_meta` version equality, `LEGACY` era test, `Mcp-Method`,
the three `Mcp-Name` key selections and the `Mcp-Name` value, completion `ref.type`, raw schema root `type`
and the `x-mcp-header` and `$ref` keys, builder enum values (also null-safe now), legacy output schema
`type`, annotation audience roles, icon theme, list and resource cache scope, and the no-variable URI
template equality. Left as is: internal constants compared with internal constants (`McpContent` block type,
`McpSchema.kind`), `Boolean`, number and null comparisons. `Map` and `Set` lookups were already exact, so tool,
prompt and resource names stay case-sensitive. URI scheme case-insensitivity in `McpIcon` is intentional.

Header names stay case-insensitive (`mcp-name`, `MCP-METHOD`; tested, and the official scenario accepts both).

Regression probes (unit tests and live): `Mcp-Method: TOOLS/LIST` for body `tools/list` is 400 `-32020`;
`Mcp-Name: ECHO` (plain and base64 encoded) for tool `echo` is 400 `-32020`; a `resources/read` `Mcp-Name` that differs by case is 400 `-32020`;
body method `Tools/List`, `TOOLS/CALL`, `Server/Discover` is 404 (modern) or 200 `-32601` (legacy); `INITIALIZE` is not `initialize`.

## 3. M3: structured and result values

Supported (walked as is, never copied, so numeric precision and nested `null` reach the wire as
`JSON.serialize` writes them): `null`, `String`, `Boolean`, `Integer`, `Long`, `Decimal`, `Double`, `Date`,
`Datetime`, `Time`, `Id`, `Blob`, `Map<String, X>`, `List<X>`, and `SObject` through
`getPopulatedFieldsAsMap()` plus a fixed 128 bytes for the `attributes` entry (measured: the estimate is within 100
bytes of `JSON.serialize` for a 30,000 character record). Typed collections work because Apex allows
`Map<String, X>` and `List<X>` as `Map<String, Object>` and `List<Object>`.

Refused before anything is serialized (`McpConfigurationException` from the walk, then `-32603` "Internal error"
and a debug log line naming the fix): `Set<T>`, `Map` with a non-`String` key, enums, custom Apex objects. The same
check covers result `_meta`, content `_meta`, embedded resource `_meta`, tool, resource and prompt `_meta`
(a refused tool `_meta` fails the whole `tools/list` page) and, at registration, `default`, `enum` and
`examples` leaves of schemas. `structured()` only stores the value; the JSON text copy is still generated after
the guard and counted twice. Pre-serialization paths checked: `toolResultMap`, `writeResult` for lists,
resources and prompts, `writeError`, registration.

Evidence (tests assert heap growth and magnitude, not only "greater than zero"):

- 20,000 item `Set<String>` (about 340 KB serialized, twice with the text copy): `-32603`, heap growth under 100,000 bytes, in modern and legacy.
- 100,000 entry `Map<Integer, Integer>` (about 1.4 MB serialized) and a `Map<Id, Integer>`: same.
- Ten `Account` records with a 32,000 character `Description` (322 KB of fields): size error, heap growth under 150,000 bytes, estimate over 320,000. Three of them fit and round trip.
- Estimate asserts exact numbers: `Map<String,String>{'k'=>'vv'}` is 11, `List<String>{'a'}` is 6, `Account(Name='x')` is 141, a 30 KB wide record within 300 bytes of `JSON.serialize`.
- Precision: `Decimal 12345678901234567890.123456789`, `Long.MAX`, `Date`, `Id`, nested nulls, `Map<String,String>` with a null value, a `List<String>` with a null all appear in the response body.

Deliberately omitted and documented (design 6.8, README, `McpToolResult.structured` Javadoc): `Set`,
non-`String` keys, enums, custom objects. Convert with `new List<String>(set)`, `String.valueOf(id)` keys, or a `Map<String, Object>`.

## 4. H1: how the guard works and what it costs

Probes on the scratch org before the design:

- `JSON.deserializeUntyped` of 2,500 nested `[` parsed in 150 ms; the following `instanceof` threw
  `System.LimitException: Maximum stack depth reached`. A handler-built `List` nested 1,500 deep passes
  `instanceof`, 3,000 deep fails it. So handler data nested thousands of levels cannot be guarded (the first
  `instanceof` is the failure); documented as a known limit.
- A regex-based strip of strings was tried first and abandoned: `replaceAll` on 240 KB throws
  `System.LimitException: Regex too complicated`, which cannot be caught.

Chosen design (native counts, then a plain scan): `countMatches('[') + countMatches('{')` at most 32 means the
text cannot be deeper, the case for every normal request (about 2 ms at 256 KiB). Otherwise one pass outside
strings. Strings are skipped with `indexOf('"')` and an odd-backslash-run check, so a bracket inside a string,
an escaped quote and an escaped backslash before the closing quote are handled. Stray closers never go below
zero and malformed text never throws in the guard: the parser reports it (`-32700`). The Apex parser is strict
Jackson (single quotes, comments and trailing commas are rejected, probed), so the lexical rules match its own.
It accepts trailing text after the first value (`[1]garbage`); the guard counts that text too, which can only
refuse more, never less.

Measured CPU of `McpWire.nestsDeeperThan` on the scratch org:

| Input | Size | CPU |
| --- | --- | --- |
| normal request, 358 bytes | 358 | 1 ms |
| 240 KB mostly string content, 40 trailing objects | 240,088 | 2 ms |
| 240 KB `[` and `]` (deep) | 240,000 | 2 ms (stops at the 33rd `[`) |
| 240 KB of `[{` inside one string | 240,004 | 2 ms |
| structure-only text: 13,000 small objects, flat numbers, 120,000 `[]` pairs | 234,000 to 240,080 | 0.99 to 1.04 s |
| 80,000 escaped quotes in one string | 160,082 | 1.13 s |

Worst case is about 1 s at 240 KB for structure-only text and about 1.8 s extrapolated for 256 KiB of escaped quotes. A
body that dense also costs the parser several seconds (4.95 s measured for the 234,000 character object body), so
the guard adds under 25% to the worst legitimate-looking request and removes the unbounded one.

Live (raw HTTP to the three endpoints): 2,500 levels in 5 KB and 119,900 levels in 240 KB both return 400
`-32600` (240 KB request answered in 261 to 328 ms round trip); 32 levels in total are still served; a body with 100
`[`, an escaped quote and 100 `{` inside a string is served.

Unit tests: boundary (32 levels pass, 33 fail, object and array mix, siblings), brackets and closers inside strings, escaped quotes and
backslashes (one, two, three, 10,000 backslashes), malformed text keeps `-32700`, estimate and guard agree on the same depth constant, CPU and heap bounds,
`WALK_MAX_DEPTH` is 32.

## 5. Contract and schema details

- `initialize` rule: bare and legacy-header `initialize` are 200; modern header and `_meta` is 404 `-32601`; modern header without `_meta` is 400 `-32602`; `_meta` without header is 400 `-32020`; mismatch is `-32020`; `2099-01-01`, `2025-06-18`, `garbage` are 400 `-32022` by header and by `_meta`. The npm proxy sends no version header on `initialize` (`protocol.ts:183`), so it is unaffected; the live bridge run proves it.
- Default tool schema: `{"type":"object","additionalProperties":false}` on the wire (unchanged), `arguments.x: is not allowed` as a tool error for any argument in both eras. A raw `inputSchema` is still trusted. One existing test (`typedGettersConvertAndRejectMismatches`) relied on the old leniency and now uses a raw object schema.
- Page size: documented in design 6.5, wire contract, README and the `pageSize` Javadoc.

## 6. Commands and results

```
sf project deploy start --source-dir force-app --target-org mcp-lib-v2-validation --wait 10
sf project deploy start --source-dir force-app --test-level RunLocalTests --target-org mcp-lib-v2-validation --wait 30   # Succeeded, 0AfG500000TFdV0KAL
sf apex run test --test-level RunLocalTests --target-org mcp-lib-v2-validation --code-coverage --result-format human --wait 20
node scripts/verify-mcp-v2.mjs --org mcp-lib-v2-validation --package-dir /tmp/mcpv2-int/consumer/node_modules/salesforce-mcp-lib \
  --tools-dir /tmp/mcpv2-int/tools --schema-dir /tmp/mcpv2-int/schema          # "144 checks, 0 failed"
# throwaway loopback shim (/tmp/mcpv2-int/shim.mjs, port 18911, killed afterwards, port confirmed free), then per scenario:
conformance server --url http://127.0.0.1:18911/ --scenario <name> --spec-version 2026-07-28 --timeout 30000
```

`inspect --help` equivalent: the script header and `--package-dir`, `--tools-dir`, `--schema-dir` usage were read first; `/tmp/mcpv2-int` was still present, so the same packed 2.0.0 tarball was reused (no TypeScript change).

| Run | Tests | Pass | Coverage |
| --- | --- | --- | --- |
| first run after the changes (`707G500001ZUTjv`) | 186 | 182 | 95%. Four failures: three from the list-of-records bug and one from the default closed schema (section 7, items 1 and 2). |
| `707G500001ZUitZ`, `ZUD1A`, `ZUcr3` | 186 | 100% | 97% |
| final `707G500001ZUkSc` | 187 | 100% | 97% |

Per class: every class with executable lines is 100% except `McpRequest` 99% (line 92, as before), `McpWire` 97%
(lines 60 and 61 `normalizeId` catch, 81 base64 catch, 140 the `return -1` Apex requires after `while (true)`) and `McpRuntime` (shown as 100%, line 271 is the
`return false` that no method reaches). `McpException` and `McpConfigurationException` have no executable lines.
Slowest new tests: `hostileStructureBodiesAreCheapToExamine` 3.4 s CPU, `hostileStringBodiesAreCheapToExamine` 1.3 s
(limit 10 s, assertion 3 s per body).

Live script, new checks (all three endpoints, 12 each): case-only differences in `Mcp-Method`, `Mcp-Name` and body method;
exact `Mcp-Name` still passes; `initialize` without version, with the legacy header, with modern headers (404), with unknown version (`-32022`);
2,500 and 119,900 levels; 32 levels served; brackets and escapes in a string.

Official conformance on `/services/apexrest/mcp/harness` (Apex directly through the shim, so not the bridge):

| Scenario | Before | Now | Remaining |
| --- | --- | --- | --- |
| `http-header-validation` | 12/13 | **14/14** | none. Includes `Server MUST reject uppercase method value (TOOLS/LIST)` and both header-name case checks. |
| `server-stateless` | 20/25 | **21/25** | `sep-2575-http-server-method-not-found-404-initialize` now passes. Four fail as "not testable": the harness has no `test_missing_capability` tool (2 checks), and the streaming-elicitation and logging fixtures (2 checks). Not claimed as passing. |

Other scenarios (`caching`, `tools-list`, `resources-list`, `prompts-list`, `sep-2164-resource-not-found`,
`dns-rebinding-protection`, `completion-complete`, `tools-call-simple-text`, `http-custom-header-server-validation`) were not rerun; the earlier results in the integration report stand.

## 7. Errors met while doing this

1. `List<Account> instanceof SObject` is true in Apex, so a list of records hit `(SObject) list` and threw `TypeException`. The walk checks `List` before `SObject` now (found by `estimateCountsEveryKindOfValue`).
2. Enforcing the default closed schema broke `typedGettersConvertAndRejectMismatches`, which called a no-schema tool with arguments. Test fixed, behaviour kept.
3. The regex strip tried for H1 raised `Regex too complicated` (uncatchable). Replaced by the character scan.
4. Apex requires a `return` after `while (true)`; removing the unreachable one failed the deploy, restored.
5. Two of my first hostile-body tests had only 20 openers and hit the native fast path, so they measured nothing; the bodies were rebuilt to exceed 32 openers and the CPU figures above come from those.
6. My first nesting test asserted the request `id` in the error; the guard runs before parsing, so the error has no `id` (like the 413). Test and docs say so.

## 8. Remaining limits and not done

- Handler-built data nested more than about 1,500 levels overflows the stack inside the first `instanceof`; nothing can guard that.
- The scan costs up to about 1 s (1.8 s for 256 KiB of escaped quotes) on a body that is also expensive to parse. If `maxRequestBytes` is raised to 1.25 MB, the worst case grows linearly.
- Estimates remain lower bounds. Text full of characters that JSON escapes still grows after serialization and is caught only by the post-serialization check (existing test `escapingGrowthIsCaughtAfterSerialization`).
- Only a debug log names the unsupported type; the client sees "Internal error". A `Set` returned from a tool fails every call of that tool until the code is fixed.
- A page of large list items can still exceed the response limit; the documented answer is a smaller `pageSize`.
- Per-tool rate limiting, SSE, tasks, MRTR, subscriptions and logging are still not implemented. Package install and upgrade are still unverified; no `04t` alias was created.
- Not reproduced here: the four fixture-dependent conformance checks, `http-custom-header-server-validation` (library does not support `x-mcp-header`).
- **Pre-delivery OCR review was not run**, because the brief says no subagents. The parent should run it with high effort (parsing, heap and limit changes). Particular attention: `McpWire.nestsDeeperThan` and `McpWire.estimateBytes`.

## 9. Files changed by this wave

Source: `McpWire`, `McpRuntime`, `McpTool`, `McpSchema`, `McpAnnotations`, `McpIcon`, `McpResourceResult`, `McpServer`,
`McpUriTemplate`, `McpToolResult` (Javadoc only). Tests: `McpWireTest`, `McpRuntimeTest`, `McpContentTest`,
`McpSchemaTest`, `McpServerTest`, `McpResourceTest`, `McpToolTest`, `McpTestKit` (`Opaque` fixture). Script:
`scripts/verify-mcp-v2.mjs` (raw probes). Docs: design (5.3, 5.4, 6.1, 6.2, 6.5, 6.8, new section 12), wire contract,
`docs/architecture.md`, root README (tool section, size guards, migration notes), and "superseded" notes in the earlier apex and integration reports.
Temporary files are in `/tmp/mcpfix` and `/tmp/mcpv2-int`; none contains a token.
`packages/salesforce-mcp-lib/README.md` needed no change (it documents the proxy only).
