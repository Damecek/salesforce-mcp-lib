# MCP wire contract: salesforce-mcp-lib 2.0.0

Date: 2026-10-28. Revision: 1, for `salesforce-mcp-lib` npm 2.0.0 and `SalesforceMcpLib` 2.0.0 (unreleased
until the package version is created). Replaces
[mcp-wire-contract-audit-2025-11-25.md](mcp-wire-contract-audit-2025-11-25.md).

This is the behaviour of the code in this repository, checked against a live scratch org for the Apex
endpoint (154 Apex tests) and against 331 npm tests for the proxy. It is a copy of the contract in
[the design](superpowers/specs/2026-10-28-mcp-v2-design.md) (sections 6 and 7) and survives edits to it.
It is not a claim of full MCP compliance. See [Known gaps](#known-gaps).

## Sources

Schema commit `271ecc9accafdd9b83a3c869fa67c22953b2af80` (2026-07-28 schema) of
[modelcontextprotocol/modelcontextprotocol](https://github.com/modelcontextprotocol/modelcontextprotocol).
Rendered spec: <https://modelcontextprotocol.io/specification/2026-07-28>. Legacy rendered spec:
<https://modelcontextprotocol.io/specification/2025-11-25>.

| Id | Source |
| --- | --- |
| S-SCHEMA | <https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/main/schema/2026-07-28/schema.ts> |
| S-CHANGE | <https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/main/docs/specification/2026-07-28/changelog.mdx> |
| S-BASIC | <https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/main/docs/specification/2026-07-28/basic/index.mdx> |
| S-VERS | <https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/main/docs/specification/2026-07-28/basic/versioning.mdx> |
| S-HTTP | <https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/main/docs/specification/2026-07-28/basic/transports/streamable-http.mdx> |
| S-STDIO | <https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/main/docs/specification/2026-07-28/basic/transports/stdio.mdx> |
| S-DISC | <https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/main/docs/specification/2026-07-28/server/discover.mdx> |
| S-CACHE | <https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/main/docs/specification/2026-07-28/server/utilities/caching.mdx> |
| S-TOOLS | <https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/main/docs/specification/2026-07-28/server/tools.mdx> |
| S-RES | <https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/main/docs/specification/2026-07-28/server/resources.mdx> |
| S-PROMPT | <https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/main/docs/specification/2026-07-28/server/prompts.mdx> |
| S-PAGE | <https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/main/docs/specification/2026-07-28/server/utilities/pagination.mdx> |
| S-COMP | <https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/main/docs/specification/2026-07-28/server/utilities/completion.mdx> |
| S-CANCEL | <https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/main/docs/specification/2026-07-28/basic/patterns/cancellation.mdx> |
| L-SCHEMA | <https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/main/schema/2025-11-25/schema.ts> |
| L-HTTP | <https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/main/docs/specification/2025-11-25/basic/transports.mdx> |
| L-LIFE | <https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/main/docs/specification/2025-11-25/basic/lifecycle.mdx> |
| SF-REST | <https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_rest_intro.htm> (6 MB synchronous request and response) |
| SF-RESP | <https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_restresponse.htm> |
| SF-HEAP | <https://help.salesforce.com/s/articleView?id=release-notes.rn_apex_heap_limit.htm&release=264.0.0&type=5> (heap 6 to 10 MB sync, 12 to 25 MB async, rolled out per instance) |
| SF-UPG | <https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_unlocked_pkg_install_pkg_upgrade.htm> |

## Eras and transport

Supported versions, in this order: `2026-07-28` (modern) and `2025-11-25` (legacy). The version decides
the era, not the shape of the body. Transport is JSON-only Streamable HTTP POST. The endpoint never
streams. `Accept` and `Content-Type` are not validated, `Mcp-Session-Id` and `Last-Event-ID` are ignored.

Observed on a scratch org (spike S0): custom MCP headers reach Apex lower-cased (`mcp-protocol-version`,
`mcp-method`, `mcp-name`), standard headers keep their casing, a mixed `Accept` does not cause a 406,
status 202 with an empty body, 400, 404, 405 (with `Allow: POST`) and 413 pass through with the Apex body.
All header reads go through one lower-cased copy.

## Apex endpoint: processing order

| # | Check | Failure response |
| --- | --- | --- |
| 1 | HTTP method is `POST` | 405, no body, `Allow: POST` |
| 2 | `Origin` absent, or exactly in the `allowOrigin` set | 403, `-32600` "Origin not allowed" |
| 3 | body bytes at most `min(maxRequestBytes, remaining heap / 8)` (default 262,144) | 413, `-32600` "Request body too large" |
| 3a | before parsing: the raw text nests `[` and `{` at most 32 levels deep (brackets inside strings do not count) | 400, `-32600` "Request structure too large", no `id` |
| 4 | body parses as JSON (an integer outside the `Long` range is a parse failure on Apex) | 400, `-32700` |
| 4a | parsed tree passes the bounded walk (depth 32, node limit from `maxRequestBytes`, 10,000 entries per collection) | 400, `-32600` "Request structure too large" |
| 5 | body is an object (arrays: "Batch requests are not supported") | 400, `-32600` |
| 6 | `jsonrpc` is `"2.0"`, `method` is a string, `id` is absent, a string or an integral number | 400, `-32600` (valid id echoed) |
| 7 | no `id`: notification | 202, no body, no handler call, no header validation |
| 8 | `method` is `initialize` and no version is named by the header or `_meta` | legacy era, continue at 11. A named version is validated like any other request (modern: `_meta` and headers, then 404 `-32601`; unknown: `-32022`; `2025-11-25`: legacy `initialize`) |
| 9 | version from `params._meta["io.modelcontextprotocol/protocolVersion"]`, else the `MCP-Protocol-Version` header. Neither present | 400, `-32020` |
| 9a | both present and different | 400, `-32020` |
| 9b | `_meta` version present, header missing | 400, `-32020` |
| 9c | version not supported | 400, `-32022`, `data: {"supported": [...], "requested": "..."}` |
| 10 | modern: `params` and `params._meta` are objects, and `_meta` carries both `io.modelcontextprotocol/protocolVersion` (string) and `io.modelcontextprotocol/clientCapabilities` (object). The header never substitutes for the `_meta` version | 400, `-32602` "Missing required _meta field: ..." |
| 10a | modern: `Mcp-Method` header present and equal to `method` | 400, `-32020` |
| 10b | `tools/call`, `prompts/get`: `params.name` is a string. `resources/read`: `params.uri` is a string | 400, `-32602` |
| 10c | modern: `Mcp-Name` header present for those three methods and its decoded value equals the 10b value | 400, `-32020` |
| 11 | method exists in the era table and its capability is advertised | modern 404, legacy 200, both `-32601` |
| 12 | dispatch to the handler | see handler errors |

`Mcp-Name` is plain visible ASCII (space and tab allowed inside) or `=?base64?<base64 of UTF-8>?=`.
A decode failure or any other value is `-32020`. Header names are case-insensitive, values are not: `Mcp-Method: TOOLS/LIST`,
`Mcp-Name: ECHO` for tool `echo` and a body method `Tools/List` are all rejected.
The legacy era skips 10 to 10c. A legacy request needs `MCP-Protocol-Version` after `initialize`, otherwise
it gets 400 `-32020`. Error responses with an unknown id carry no `id`.

## Method tables

| Method | Modern | Legacy | Capability present only when |
| --- | --- | --- | --- |
| `server/discover` | yes | no | always |
| `initialize` | no (404 when a modern version is named) | yes | always |
| `ping` | no | yes | always |
| `tools/list`, `tools/call` | yes | yes | at least one tool |
| `resources/list`, `resources/read`, `resources/templates/list` | yes | yes | at least one resource or template |
| `prompts/list`, `prompts/get` | yes | yes | at least one prompt |
| `completion/complete` | yes | yes | at least one prompt or template |

Capabilities object: `tools: {}`, `resources: {}`, `prompts: {}`, `completions: {}` under those gates. No
`listChanged`, `subscribe`, `logging`, `extensions` or `experimental`.

## Results

Modern results always carry `resultType: "complete"` and
`_meta["io.modelcontextprotocol/serverInfo"]` (the framework key wins over a handler `_meta` key). The six
cacheable results (`server/discover`, the four list methods, `resources/read`) carry `ttlMs`
and `cacheScope`, default `0` and `"private"`. Legacy results carry none of the three.

| Method | Result |
| --- | --- |
| `server/discover` | `supportedVersions`, `capabilities`, `instructions?` |
| `initialize` | `protocolVersion: "2025-11-25"` always, `capabilities`, `serverInfo`, `instructions?` |
| `ping` | `{}` |
| `tools/list`, `resources/list`, `resources/templates/list`, `prompts/list` | the list and `nextCursor?` |
| `tools/call` | `content`, `structuredContent?`, `isError?` |
| `resources/read` | `contents` |
| `prompts/get` | `description?`, `messages` |
| `completion/complete` | `completion: {values (at most 100), total?, hasMore?}` |

Legacy differences: `outputSchema` is dropped from `tools/list` when its root `type` is not `"object"`.
`structuredContent` that is not an object is dropped from `tools/call`, and when `content` is then empty a
text block with the serialized value is added. Resource not found is `-32602` (modern) or `-32002` (legacy).

## Handler errors, statuses, pagination

| Case | Code | HTTP |
| --- | --- | --- |
| unknown tool or prompt, `arguments` not an object, bad or missing prompt argument, invalid cursor, unknown completion ref or argument | `-32602` | 200 |
| resource not found | `-32602` modern, `-32002` legacy | 200 |
| argument schema failure, `McpException` in a tool | result with `isError: true` | 200 |
| unexpected exception, output schema mismatch, missing `structuredContent` for a builder `outputSchema` | `-32603` "Internal error" | 200 |
| response too large | `-32603` "Response exceeds the server size limit" | 200 |

Successful responses are 200 with `Content-Type: application/json`. Handler errors use 200 because
legacy SDK clients drop the JSON-RPC body on non-2xx statuses. Pagination: opaque cursor, registration
order, page size 50 (setter accepts 1 to 100), invalid cursor is `-32602`. A page that exceeds the response
limit is the size error; there is no adaptive paging, so set a smaller `pageSize` for large items.

## Size and heap guards

Request and response limits default to 262,144 bytes (256 KiB), settable from 1,024 to 6,000,000. The effective
request limit is `min(maxRequestBytes, remaining heap / 8)`. The effective response limit is
`min(maxResponseBytes, remaining heap / 3)`. The response is estimated by an iterative bounded walk before
`JSON.serialize` and measured again after it. `McpToolResult.structured(...)` counts its data twice, because
it also emits a JSON text copy. Result values must be JSON-native (`Map<String, X>`, `List<X>`, scalars, `Blob`,
`SObject` by its populated fields); a `Set`, a `Map` with a non-`String` key, an enum or a custom object is refused
with `-32603` "Internal error" before anything is serialized. Nothing is truncated. The guards are heuristics: they reduce the chance of an
uncatchable `LimitException` and do not bound CPU or heap used by handler code.

## stdio proxy

| Input line | Action |
| --- | --- |
| longer than 6 MiB (6,291,456 bytes) | discard through the next newline, `-32600` without id |
| not JSON, or invalid UTF-8 | `-32700` without id |
| JSON array | `-32600` "Batch requests are not supported" without id |
| object without `method`, with `id` and `result` or `error` | dropped (client response) |
| any other object without `method`; id that is not a string or safe integer | `-32600` |
| `notifications/cancelled` | handled locally: aborts the queued or in-flight request for `params.requestId`, suppresses its response, is never forwarded. Work Apex already started still completes |
| other notification | forwarded, nothing written (warning log for non-2xx) |
| request id already queued or in flight | `-32600` "Duplicate request id" without `id` |
| request | queued, forwarded |

Outbound headers: `Content-Type: application/json`, `Accept: application/json, text/event-stream`,
`Authorization: Bearer ...`, `Content-Length`. A message with `params._meta["io.modelcontextprotocol/protocolVersion"]`
gets `MCP-Protocol-Version`, `Mcp-Method`, and `Mcp-Name` for `tools/call`, `prompts/get` and `resources/read`.
`initialize` gets none. Other messages get the `MCP-Protocol-Version` taken from the last successful
`initialize` result. A malformed modern version, or a method over 256 chars, is `-32600` locally.

| Remote result | Output |
| --- | --- |
| 202 or 204 | nothing (valid only for notifications; for a request it is a local error) |
| 401 `INVALID_SESSION_ID` | re-authenticate once, retry once; parallel 401s share one token request |
| JSON-RPC object with `jsonrpc: "2.0"`, exactly one of `result`/`error`, valid `error.code` and `error.message` | written as one line with only inter-token whitespace removed, so number spelling is lossless. Response id mismatch is a local error; an error without id gets the request id |
| 200 with empty body, Salesforce error array, HTML, network error | local error `-32603` with `data.source = "salesforce-mcp-lib-proxy"` and `httpStatus` |
| body over 8 MiB, or no response within `--request-timeout-ms` (covers authentication, retry and response) | abort, local error |

Limits: request timeout 1,000 to 600,000 ms (default 120,000), concurrency 1 to 25 (default 4), queue of 64
requests, 64 MiB of queued plus in-flight line bytes, OAuth calls 30 s total with a 1 MiB body cap (separate from
the request timeout). `--instance-url` and `--endpoint` must be https, except exact loopback addresses used for
tests. Remote bodies, tokens and secrets never reach logs or local errors. On stdin end the proxy drains
queued and in-flight requests, then exits 0.

## Known gaps

Not implemented, absent from capabilities, answered with `-32601`: SSE responses, `subscriptions/listen`, list-changed
and resource-updated notifications, `resources/subscribe`, MRTR (`input_required`), elicitation, sampling, roots,
tasks, progress notifications, logging, protocol sessions, `x-mcp-header`/`Mcp-Param-*`, JSON-RPC batches,
protocol versions older than 2025-11-25, and the old nonstandard `resources/templates/call`.

**Per-tool rate limiting is not implemented.** S-TOOLS says servers MUST rate limit tool invocations. A counter
needs SOQL, DML or Platform Cache, which the governor-limit priority rules out. The framework relies on
Salesforce API request limits and concurrent request limits. Because of this gap, this library does not claim
full MCP 2026-07-28 compliance.

Package installation and upgrade of the 2.0.0 unlocked package is not yet verified: all evidence comes from source
deploys to a scratch org.
