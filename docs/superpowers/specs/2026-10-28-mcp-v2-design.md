# salesforce-mcp-lib v2 design: dual-era MCP (2026-07-28 + 2025-11-25)

Date: 2026-10-28. Status: approved for implementation by the parent agent. Breaking release.

Targets: npm `salesforce-mcp-lib@2.0.0`, Salesforce unlocked package `SalesforceMcpLib@2.0.0-x`
(same package `0HodL0000002PQXSA2`, `versionNumber: 2.0.0.NEXT`).

Priorities, in order: Apex governor limits, then performance, then the widest MCP
compatibility we can implement for real. We do not advertise a feature or version that we do not
actually implement.

## 1. Sources

All normative statements below were checked against raw files from
`modelcontextprotocol/modelcontextprotocol` at `main`, schema commit
`271ecc9accafdd9b83a3c869fa67c22953b2af80` (2026-07-28). Rendered pages live under
`https://modelcontextprotocol.io/specification/2026-07-28/...`.

| Id | Source |
| --- | --- |
| S-SCHEMA | https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/main/schema/2026-07-28/schema.ts |
| S-CHANGE | https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/main/docs/specification/2026-07-28/changelog.mdx |
| S-BASIC | .../docs/specification/2026-07-28/basic/index.mdx (messages, error codes, `_meta`, JSON Schema usage) |
| S-VERS | .../docs/specification/2026-07-28/basic/versioning.mdx (eras, compatibility matrix) |
| S-HTTP | .../docs/specification/2026-07-28/basic/transports/streamable-http.mdx |
| S-STDIO | .../docs/specification/2026-07-28/basic/transports/stdio.mdx |
| S-DISC | .../docs/specification/2026-07-28/server/discover.mdx |
| S-CACHE | .../docs/specification/2026-07-28/server/utilities/caching.mdx |
| S-TOOLS | .../docs/specification/2026-07-28/server/tools.mdx |
| S-RES | .../docs/specification/2026-07-28/server/resources.mdx |
| S-PROMPT | .../docs/specification/2026-07-28/server/prompts.mdx |
| S-PAGE | .../docs/specification/2026-07-28/server/utilities/pagination.mdx |
| S-COMP | .../docs/specification/2026-07-28/server/utilities/completion.mdx |
| S-CANCEL | .../docs/specification/2026-07-28/basic/patterns/cancellation.mdx |
| L-SCHEMA | https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/main/schema/2025-11-25/schema.ts |
| L-HTTP | .../docs/specification/2025-11-25/basic/transports.mdx |
| L-LIFE | .../docs/specification/2025-11-25/basic/lifecycle.mdx |
| SF-REST | https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_rest_intro.htm (6 MB sync request/response) |
| SF-RESP | https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_restresponse.htm (allowed status codes, forbidden headers) |
| SF-HEAP | https://help.salesforce.com/s/articleView?id=release-notes.rn_apex_heap_limit.htm&release=264.0.0&type=5 (Winter '27 heap 6→10 MB sync, 12→25 MB async) |
| SF-UPG | https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_unlocked_pkg_install_pkg_upgrade.htm |

## 2. Corrections to earlier research

1. **Heap "10 MB".** Partly true. Winter '27 (release 264) raises the synchronous heap from 6 MB
   to 10 MB and async from 12 MB to 25 MB, rolled out per instance. Sandboxes and scratch orgs can
   enforce the Summer '26 limit through Apex Settings (SF-HEAP). The Apex REST guide still states a
   6 MB synchronous request and response limit (SF-REST). Decision: the code never assumes a heap
   size. It reads `Limits.getLimitHeapSize()` and `Limits.getHeapSize()` at runtime. Request and response
   bodies default to 262,144 bytes (256 KiB, parent override). `maxRequestBytes` and `maxResponseBytes`
   may be raised up to the 6,000,000-byte platform ceiling (SF-REST), and the runtime additionally
   caps them by the remaining heap (section 6.8). Scratch org S0 measurement: sync heap 10,000,000.
2. **Discovery caching.** The changelog's caching item lists only the four list methods and
   `resources/read`. That list is incomplete. S-CACHE names `server/discover` first, and
   `DiscoverResult extends CacheableResult` in S-SCHEMA. So `server/discover` **MUST** carry
   `ttlMs` and `cacheScope`.
3. **No discovery bootstrap exception.** `DiscoverRequest.params: RequestParams`, and
   `RequestParams._meta` requires `io.modelcontextprotocol/protocolVersion` and
   `io.modelcontextprotocol/clientCapabilities`. On HTTP, `MCP-Protocol-Version` and `Mcp-Method`
   are required on every POST, discovery included. The bootstrap mechanism is the
   `UnsupportedProtocolVersionError` (`-32022`) that lists `supported`, not a relaxed discover.
   The only header exemptions are the legacy `initialize` request (L-HTTP: header required on
   "subsequent" requests) and notification POSTs (S-HTTP: "header requirements for notification
   POSTs are not defined by this revision").
4. **Error codes were renumbered.** `HeaderMismatch` is `-32020`, `MissingRequiredClientCapability`
   is `-32021`, `UnsupportedProtocolVersion` is `-32022`. Earlier drafts used `-32001/-32003/-32004`.
   Modern servers **MUST NOT** emit `-32002`. Resource not found is `-32602` in the modern era and
   `-32002` in 2025-11-25, so the code is era-specific.
5. **HTTP status is part of the contract in the modern era.** Unknown method **MUST** be HTTP 404
   with `-32601`. Header failures, unsupported version, and missing required `_meta` fields
   **MUST** be HTTP 400. The 2025-11-25 transport does not define statuses for JSON-RPC errors.
6. **Unlocked packages have no ancestors.** `ancestorId`/`ancestorVersion` apply to managed 2GP only.
   Keep the package id, bump `versionNumber` to `2.0.0.NEXT`. Nothing forces a new package.
7. **Cancellation is transport-specific.** `notifications/cancelled` is stdio-only. On Streamable
   HTTP, closing the response stream cancels. The stdio proxy therefore handles cancellation
   locally and never forwards it to Apex.
8. **Schema shapes differ by era.** Modern `structuredContent` is any JSON value and `outputSchema`
   any JSON Schema. Legacy (L-SCHEMA) requires `structuredContent` to be an object and
   `outputSchema.type` to be `"object"`.
9. **`resultType` is required on every modern result.** Cache fields are required only on the six
   cacheable methods, and only when `resultType` is `"complete"`.

## 3. Scope

### 3.1 Implemented

| Area | Modern 2026-07-28 | Legacy 2025-11-25 |
| --- | --- | --- |
| Lifecycle | stateless per-request `_meta`, `server/discover` | `initialize`, `notifications/initialized`, `ping` |
| Tools | `tools/list` (paged), `tools/call`, `title`, `icons`, `annotations`, `_meta`, `outputSchema`, `structuredContent` | same, object-only structured output |
| Content blocks | text, image, audio, resource_link, embedded resource, annotations, `_meta` | same |
| Resources | `resources/list`, `resources/read` (static and template routing), `resources/templates/list` | same |
| Prompts | `prompts/list`, `prompts/get` with any content block | same |
| Completions | `completion/complete` for prompt arguments and template variables | same |
| Caching | `ttlMs`/`cacheScope` on the six cacheable results, default `0`/`"private"` | not emitted |
| Pagination | opaque cursor, server-chosen page size | same |
| Transport | JSON-only Streamable HTTP POST, header validation, Origin allowlist | JSON-only POST, no session id |

### 3.2 Not implemented, by decision

Each item is absent from capabilities and returns `-32601`, so no client is misled.

- SSE responses, `subscriptions/listen`, list-changed and resource-updated notifications,
  `resources/subscribe`. Apex REST cannot hold a stream open.
- MRTR (`input_required`), elicitation, sampling, roots. They need server-to-client input; MRTR is
  a later candidate. Because the server never needs client capabilities, it never emits `-32021`.
- Tasks extension, progress notifications, logging (`logging/setLevel`, `notifications/message`,
  per-request `logLevel` is accepted and ignored, which S-SCHEMA allows because nothing is emitted).
- Protocol-level sessions. `Mcp-Session-Id` and `Last-Event-ID` are ignored.
- `x-mcp-header` / `Mcp-Param-*`. The Salesforce endpoint sits behind Salesforce's own gateway, so
  header-routed intermediaries add nothing. Registration rejects any schema containing
  `x-mcp-header`, so the server never has to validate `Mcp-Param-*` headers.
- JSON-RPC batches. Both eras forbid them. Arrays get `-32600` with HTTP 400.
- Protocol versions 2025-06-18, 2025-03-26, 2024-11-05. They are not advertised because the server
  does not implement their differences (batching in 2025-03-26, no `icons` in 2025-06-18).
  A legacy `initialize` asking for them gets `protocolVersion: "2025-11-25"`, which L-LIFE requires.
- Per-tool rate limiting. S-TOOLS says servers MUST rate limit tool invocations. The framework relies
  on Salesforce org API request limits and concurrent request limits and adds no counter, because a
  counter needs storage (SOQL/DML or Platform Cache), which the governor priority excludes.
  Documented as a known gap in the README.
- The nonstandard `resources/templates/call` method is removed. Templates are read through
  `resources/read`.

## 4. Architecture decision: rebuild the Apex core, keep the shape

The existing code has 62 Apex classes. The generic JSON-RPC layer (13 classes) carries batch
support, unused `paramsType`/`resultType`, `JsonRpcParamsBase`, `JsonRpcResultBase`, and an id type
that truncates `Long` ids through `intValue()`. Its hand-built serializer escapes only `"`, so an
error message with a backslash or newline produces invalid JSON, and it serializes results with
`suppressApexObjectNulls=true`, which drops legitimate `null` values from tool output. It has no
place for era, headers, or HTTP status. Several MCP DTOs (`McpInitialize*`, `McpNamedArgumentsParams`,
`McpToolAnnotationsWire`) are unused.

Decision: delete `force-app/main/json-rpc` and the old MCP classes, and build about 24 focused
classes in `force-app/main/mcp/classes`. A small refactor would keep the broken parts (id handling,
serializer, batch path) and still need new era and status plumbing, so it costs more than a rebuild.
The public concepts stay: `McpServer`, tool, resource, template, and prompt definitions.

Rules that apply to every Apex class:

- No SOQL, DML, callouts, Platform Cache, or custom objects in the framework.
- No static mutable state. The only statics are `final` constants. One `McpRuntime` instance per
  HTTP request holds the era and protocol version.
- Wire output is built as `Map<String, Object>` and serialized once with
  `JSON.serialize(envelope)` (never `suppressApexObjectNulls=true`). Builders never put `null` values,
  so only user data can contain `null`.
- Registration is O(1) per definition plus a bounded schema walk. Handlers are invoked only for the
  method being served.
- Classes are `public` (the package has no namespace, so subscriber code can reference them) and use
  `inherited sharing`.

## 5. Apex public API (contract C1)

All method names avoid Apex reserved words (`number`, `object`, `type`, `desc`, `default`, `enum`,
`array`, `limit`, `sort`). Fluent setters return the receiver. Private fields use distinct names
(for example `titleText`), never the same name as a method.

```apex
@RestResource(urlMapping='/mcp/*')
global with sharing class AcmeMcpEndpoint {
    @HttpPost
    global static void post() {
        new McpServer('acme-sales', '1.0.0')
            .instructions('Call search_accounts before create_case.')
            .tool(new SearchAccountsTool())
            .resource(new OrgInfoResource())
            .resourceTemplate(new AccountResourceTemplate())
            .prompt(new SummarizeAccountPrompt())
            .handle(RestContext.request, RestContext.response);
    }
}

public with sharing class SearchAccountsTool extends McpTool {
    public SearchAccountsTool() {
        super('search_accounts');
        title('Search accounts')
            .description('Finds accounts by name prefix.')
            .input(McpSchema.obj()
                .requiredProperty('prefix', McpSchema.str().minLength(2).maxLength(80))
                .property('limit', McpSchema.integer().minimum(1).maximum(50)))
            .output(McpSchema.obj()
                .requiredProperty('accounts', McpSchema.arr(McpSchema.obj()
                    .requiredProperty('id', McpSchema.str())
                    .requiredProperty('name', McpSchema.str()))))
            .annotations(new McpToolAnnotations().readOnly(true).openWorld(false));
    }
    public override McpToolResult execute(McpRequest request) {
        String prefix = request.requireString('prefix') + '%';
        Integer max = request.getInteger('limit') == null ? 10 : request.getInteger('limit');
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        for (Account a : [SELECT Id, Name FROM Account WHERE Name LIKE :prefix
                          WITH USER_MODE LIMIT :max]) {
            rows.add(new Map<String, Object>{ 'id' => a.Id, 'name' => a.Name });
        }
        return McpToolResult.structured(new Map<String, Object>{ 'accounts' => rows });
    }
}
```

### 5.1 Class list and signatures

| Class | Kind | Members (all `public` unless noted) |
| --- | --- | --- |
| `McpServer` | concrete | `McpServer(String name, String version)`; `title(String)`, `description(String)`, `websiteUrl(String)`, `icon(McpIcon)`, `instructions(String)`, `tool(McpTool)`, `resource(McpResource)`, `resourceTemplate(McpResourceTemplate)`, `prompt(McpPrompt)`, `allowOrigin(String)`, `listCache(Integer ttlMs, String scope)`, `pageSize(Integer)`, `maxRequestBytes(Integer)`, `maxResponseBytes(Integer)`, `skipOutputValidation()` all return `McpServer`; `void handle(RestRequest, RestResponse)`; constants `CACHE_PUBLIC='public'`, `CACHE_PRIVATE='private'` |
| `McpTool` | abstract | `McpTool(String name)`; `title`, `description`, `icon(McpIcon)`, `annotations(McpToolAnnotations)`, `meta(String key, Object value)`, `input(McpSchema)`, `inputSchema(Map<String,Object>)`, `output(McpSchema)`, `outputSchema(Map<String,Object>)` return `McpTool`; `virtual void validate(McpRequest)`; `abstract McpToolResult execute(McpRequest)`; `String getName()` |
| `McpToolResult` | concrete | `static text(String)`, `static structured(Object)` (adds a JSON text block, S-TOOLS SHOULD), `static error(String)`; `add(McpContent)`, `structuredContent(Object)`, `markError()`, `meta(String, Object)` |
| `McpToolAnnotations` | concrete | `title(String)`, `readOnly(Boolean)`, `destructive(Boolean)`, `idempotent(Boolean)`, `openWorld(Boolean)` |
| `McpContent` | concrete | `static text(String)`, `static image(Blob, String mimeType)`, `static imageBase64(String, String)`, `static audio(Blob, String)`, `static audioBase64(String, String)`, `static resourceLink(String uri, String name)`, `static embedded(McpResourceContents)`; chain `annotations(McpAnnotations)`, `meta(String,Object)`; link-only chain `title`, `description`, `mimeType`, `size(Long)`, `icon(McpIcon)` (throw `McpConfigurationException` on a non-link block) |
| `McpResourceContents` | concrete | `static text(String uri, String mimeType, String text)`, `static blob(String uri, String mimeType, Blob data)`, `static blobBase64(String, String, String)`; `meta(String,Object)` |
| `McpAnnotations` | concrete | `audience(List<String>)` (`user`/`assistant`), `priority(Decimal)` (0..1), `lastModified(Datetime)`, `lastModified(String)` |
| `McpIcon` | concrete | `McpIcon(String src)` (`https:` or `data:` only); `mimeType(String)`, `sizes(List<String>)`, `theme(String)` (`light`/`dark`) |
| `McpSchema` | concrete | `static str()`, `integer()`, `num()`, `bool()`, `obj()`, `arr(McpSchema items)`, `enumOf(List<String>)`; chain `property(String, McpSchema)`, `requiredProperty(String, McpSchema)`, `closed()` (`additionalProperties:false`), `nullable()`, `title(String)`, `describe(String)`, `defaultValue(Object)`, `format(String)` (annotation only), `minLength`, `maxLength`, `minimum(Decimal)`, `maximum(Decimal)`, `minItems`, `maxItems`; `Map<String,Object> toMap()` |
| `McpResource` | abstract | `McpResource(String uri, String name)`; `title`, `description`, `mimeType`, `size(Long)`, `annotations(McpAnnotations)`, `icon`, `meta`; `abstract McpResourceResult read(McpRequest)` |
| `McpResourceTemplate` | abstract | `McpResourceTemplate(String uriTemplate, String name)`; same metadata minus `size`; `abstract McpResourceResult read(McpRequest)` (return `null` for not found); `virtual McpCompletion complete(String argumentName, String value, Map<String,String> context)` |
| `McpResourceResult` | concrete | `static of(McpResourceContents)`; `add(McpResourceContents)`, `cache(Integer ttlMs, String scope)`, `meta(String,Object)` |
| `McpPrompt` | abstract | `McpPrompt(String name)`; `title`, `description`, `icon`, `meta`, `argument(String name, String description, Boolean required)`; `abstract McpPromptResult get(McpRequest)`; `virtual McpCompletion complete(String, String, Map<String,String>)` |
| `McpPromptResult` | concrete | `description(String)`, `user(McpContent)`, `assistant(McpContent)`, `meta(String,Object)` |
| `McpCompletion` | concrete | `static of(List<String>)`, `static none()`; `total(Integer)`, `hasMore(Boolean)` |
| `McpRequest` | concrete, built by framework | `method()`, `protocolVersion()`, `isLegacy()`, `clientInfo()`, `clientCapabilities()`, `meta()`; tools: `name()`, `arguments()` (never null), `get(String)`, `getString`, `requireString`, `getInteger`, `getLong`, `getDecimal`, `getBoolean`, `getMap`, `getList`; prompts: `promptArguments()`; resources: `uri()`, `variable(String)`; test helpers `static forTool(String name, Map<String,Object> args)`, `static forPrompt(String, Map<String,String>)`, `static forResource(String uri)` |
| `McpException` | exception | message is safe to show to the client |
| `McpConfigurationException` | exception | developer error at registration; never shown to clients |

Internal classes (not part of the supported API, still `public` for cross-class access):
`McpRuntime` (pipeline), `McpWire` (serialization), `McpUriTemplate` (RFC 6570 level-1 parser and
matcher), `McpProtocolException` (carries `code`, `message`, `data`, `httpStatus`).

Typed getters on `McpRequest` throw `McpException('Argument "x" must be a string')` on a type
mismatch. `getInteger` accepts `Integer`, `Long` within range, and `Decimal` with no fractional part.

### 5.2 Error semantics for handler code

| Thrown in | `McpException` | any other `Exception` |
| --- | --- | --- |
| `McpTool.validate` / `execute` | result with `isError: true`, its message as text | JSON-RPC `-32603` `"Internal error"` |
| `McpPrompt.get`, `McpResource*.read`, `complete` | JSON-RPC `-32602` with its message | JSON-RPC `-32603` `"Internal error"` |

Internal errors are logged with `System.debug(LoggingLevel.ERROR, ...)` including type, message and
stack. The client never sees exception text unless the developer threw `McpException`.
`System.LimitException` cannot be caught in Apex. A handler that exhausts limits produces a
Salesforce platform error response, not a JSON-RPC envelope. The proxy turns that into a local
error (section 8). The framework guards do not prevent a handler from exhausting limits.

The size guards in section 6.8 reduce the chance of exhausting the heap, but they do not prevent a
`LimitException` raised inside a handler, and they do not bound CPU or heap used by handler code.

Side effects: when `execute` succeeds and the response is then rejected as too large, DML done by
the tool is already committed. Tools should bound their own output. The framework adds no savepoint
because a savepoint counts against the DML statement limit.

### 5.3 Registration validation (throws `McpConfigurationException`)

- Tool and prompt names: 1 to 128 chars from `[A-Za-z0-9_.-]`, unique per kind. This is stricter
  than the S-TOOLS SHOULD and keeps every name header-safe.
- Resource URIs: scheme `[A-Za-z][A-Za-z0-9+.-]*:` and length ≤ 2048, unique.
- Templates: level-1 RFC 6570 only (`{var}`, var names `[A-Za-z0-9_]+`, no adjacent expressions,
  no operators `+ # . / ; ? &`). Unique by template string.
- Input schema root `type` must be `"object"`. Raw schemas get an iterative (non-recursive) bounded
  walk that counts every value, including data-like leaves (`enum`, `default`, `examples`, `const`):
  depth ≤ 16, ≤ 1,000 nodes in total, ≤ 200 entries in any one collection; any `x-mcp-header` key
  anywhere is rejected; `$ref` values must start with `#` (S-BASIC forbids auto-dereferencing network
  refs). Cyclic maps fail the depth limit. Builder (`McpSchema`) schemas go through the same walk.
- Output schemas: same walk; root may be any type.
- Icons: `src` scheme `https:` or `data:`.
- A tool without `input(...)` or `inputSchema(...)` emits `{"type":"object","additionalProperties":false}`
  (S-TOOLS recommendation for parameterless tools) and the framework enforces it: any argument is the
  tool error `arguments.<name>: is not allowed`. A raw `inputSchema(Map)` stays trusted and is not enforced.
- Schema leaves (`default`, `enum`, `examples`, `_meta`-like data) must be JSON-native scalars, maps or
  lists. A `Set`, an `SObject` or a custom object anywhere in a schema fails registration.

### 5.4 Validation subset (honest)

`McpSchema` builders validate arguments before `validate()` and `execute()` run. Supported keywords:
`type` (string, integer, number, boolean, object, array, plus `null` via `nullable()`), `properties`,
`required`, `additionalProperties: false`, `enum` (strings), `minLength`, `maxLength`, `minimum`,
`maximum`, `minItems`, `maxItems`, `items` (single schema). `enum` values and every other string the
wire contract defines (method, header values, `type`, roles, themes, cache scopes) are compared
case-sensitively: Apex `==` ignores case, so the code uses `McpWire.same(...)`. `title`, `description`, `default` and
`format` are emitted but not validated. `pattern`, composition, conditionals and `$ref` are not
offered by the builder.

Raw schemas (`inputSchema(Map)`) are trusted: the framework checks only that `arguments` is an object,
and the tool's `validate()` must do the rest. This is the "explicit trusted custom validator" path.

Validation stops after 10 errors and reports them in one `isError` result. Output validation runs
the same subset on `structuredContent` for builder output schemas when `isError` is not set. A
mismatch is a server bug and returns `-32603`. `skipOutputValidation()` turns it off and is
documented as "the developer asserts conformance" (S-TOOLS: servers MUST conform).

## 6. HTTP wire contract (contract C2, Apex endpoint)

Constants: `MODERN = '2026-07-28'`, `LEGACY = '2025-11-25'`,
`SUPPORTED = ['2026-07-28', '2025-11-25']` (order matters, used in `-32022` data and discovery).

### 6.1 Processing order

Headers are read through one lower-cased copy of `RestRequest.headers` (Salesforce casing is not
documented). Error responses with unknown id omit `id` (allowed by both S-SCHEMA and L-SCHEMA).

| # | Check | Failure response |
| --- | --- | --- |
| 1 | `req.httpMethod == 'POST'` | 405, no body, `Allow: POST` |
| 2 | `Origin` absent, or exact match in `allowOrigin` set | 403, `{"jsonrpc":"2.0","error":{"code":-32600,"message":"Origin not allowed"}}` |
| 3 | body bytes ≤ min(`maxRequestBytes` (default 262,144), remaining heap / 8) | 413, `-32600` `"Request body too large"` |
| 3a | **before parsing**: the raw text nests containers at most `McpWire.WALK_MAX_DEPTH` (32) levels deep (`McpWire.nestsDeeperThan`, strings and escapes aware) | 400, `-32600` `"Request structure too large"` (no `id`: nothing is parsed) |
| 4 | body parses as JSON (a number outside the `Long` range is a parse failure on Apex) | 400, `-32700` |
| 4a | parsed tree passes the bounded walk (depth ≤ 32, ≤ `nodeLimit(maxRequestBytes)` nodes, ≤ 10,000 entries per collection) | 400, `-32600` `"Request structure too large"` |
| 5 | body is an object (arrays: `"Batch requests are not supported"`) | 400, `-32600` |
| 6 | `jsonrpc == "2.0"`, `method` is a string, `id` absent or string or integral number | 400, `-32600` (id echoed when valid) |
| 7 | no `id`: notification | 202, no body, no handler call, no header validation |
| 8 | `method` is exactly `"initialize"` **and neither the header nor `_meta` names a version** | legacy era, skip to 11. With any explicit version the request takes steps 9 to 10c like every other method: modern gives `-32602` for a missing `_meta` field, `-32020` for a header problem and then 404 `-32601` (initialize does not exist in the modern era); an unknown version gives `-32022`; `2025-11-25` is served as legacy `initialize` |
| 9 | version = `params._meta["io.modelcontextprotocol/protocolVersion"]` else header `MCP-Protocol-Version`. Neither: | 400, `-32020` `"Missing MCP-Protocol-Version header"` |
| 9a | both present and different | 400, `-32020` |
| 9b | `_meta` version present, header missing | 400, `-32020` |
| 9c | version not in `SUPPORTED` | 400, `-32022`, `data: {"supported": SUPPORTED, "requested": version}` |
| 10 | version == MODERN: `params` object, `params._meta` object, and **both** required fields present in `_meta`: `io.modelcontextprotocol/protocolVersion` (string) and `io.modelcontextprotocol/clientCapabilities` (object). The header never substitutes for the `_meta` version. | 400, `-32602` `"Missing required _meta field: <field>"` |
| 10a | header `Mcp-Method` present and equal to `method` (absent is a failure: S-HTTP "REQUIRED") | 400, `-32020` |
| 10b | `tools/call`, `prompts/get`: `params.name` string; `resources/read`: `params.uri` string | 400, `-32602` |
| 10c | header `Mcp-Name` present (required for these three methods) and its decoded value equals the 10b value | 400, `-32020` |
| 11 | method exists in era table and its capability is advertised | modern: 404 `-32601`; legacy: 200 `-32601` |
| 12 | dispatch handler | see 6.3 |

`Mcp-Name` decoding: if the value starts with `=?base64?` and ends with `?=`, base64-decode the middle
as UTF-8; decode failure is `-32020`. Plain values must be visible ASCII or space or tab (S-HTTP
value encoding), otherwise `-32020`. Header names are case-insensitive; values are case-sensitive.
Every method, header value and enum comparison is exact (`McpWire.same`): `Mcp-Method: TOOLS/LIST` for body
`tools/list`, `Mcp-Name: ECHO` for tool `echo` and a body method `Tools/List` all fail (`-32020`, `-32020`,
`-32601`). The method must be a member of a case-sensitive set before any other comparison.
`Mcp-Session-Id`, `Last-Event-ID`, `Accept`, and `Content-Type` are not validated.

Legacy era (version `2025-11-25` or method `initialize`) skips 10 to 10c. A modern-shaped body that
declares `2025-11-25` in `_meta` is served as legacy; the version decides the era, not the shape.

### 6.2 Era method tables

| Method | Modern | Legacy | Gate (capability present only when) |
| --- | --- | --- | --- |
| `server/discover` | yes | no | always |
| `initialize` | no (404 `-32601` when a modern version is named) | yes (also when no version is named) | always |
| `ping` | no | yes | always |
| `tools/list`, `tools/call` | yes | yes | ≥1 tool |
| `resources/list`, `resources/read`, `resources/templates/list` | yes | yes | ≥1 resource or template |
| `prompts/list`, `prompts/get` | yes | yes | ≥1 prompt |
| `completion/complete` | yes | yes | ≥1 prompt or template |

Capabilities object (both eras): `tools: {}`, `resources: {}`, `prompts: {}`, `completions: {}`
under the gates above. No `listChanged`, `subscribe`, `logging`, `extensions`, or `experimental`.

### 6.3 Results

Modern results always get `resultType: "complete"` and
`_meta["io.modelcontextprotocol/serverInfo"] = {name, version, title?, description?, websiteUrl?, icons?}`
merged over any handler `_meta` (framework key wins). Cacheable methods also get `ttlMs` and
`cacheScope`. Legacy results get none of these three.

| Method | Result body (before decoration) | Cache fields (modern) |
| --- | --- | --- |
| `server/discover` | `supportedVersions: SUPPORTED`, `capabilities`, `instructions?` | `listCache` (default `0`, `"private"`) |
| `initialize` (legacy) | `protocolVersion: "2025-11-25"` always, `capabilities`, `serverInfo`, `instructions?` | n/a |
| `ping` (legacy) | `{}` | n/a |
| `tools/list` | `tools: [Tool]`, `nextCursor?` | `listCache` |
| `tools/call` | `content`, `structuredContent?`, `isError?` | none |
| `resources/list` | `resources: [Resource]`, `nextCursor?` | `listCache` |
| `resources/templates/list` | `resourceTemplates: [ResourceTemplate]`, `nextCursor?` | `listCache` |
| `resources/read` | `contents: [...]` | from `McpResourceResult.cache`, default `0`/`"private"` |
| `prompts/list` | `prompts: [Prompt]`, `nextCursor?` | `listCache` |
| `prompts/get` | `description?`, `messages` | none |
| `completion/complete` | `completion: {values ≤ 100, total?, hasMore?}` | none |

Era-specific serialization:

- Legacy `tools/list`: drop `outputSchema` when its root `type` is not `"object"`.
- Legacy `tools/call`: drop `structuredContent` when it is not a `Map`. If `content` is then empty,
  add a text block with the serialized value so the data still reaches the client.
- Resource not found: modern `-32602`, legacy `-32002`, message `"Resource not found"`, `data: {"uri": uri}`.

### 6.4 Handler-level errors and statuses

| Case | Code | HTTP |
| --- | --- | --- |
| unknown tool or prompt, `arguments` not an object, prompt argument not a string, missing required prompt argument, invalid cursor, unknown completion ref | `-32602` | 200 |
| resource not found | `-32602` modern / `-32002` legacy | 200 |
| argument schema failure, `McpException` in a tool | result `isError: true` | 200 |
| unexpected exception, output schema mismatch, missing `structuredContent` for a builder `outputSchema` | `-32603` `"Internal error"` | 200 |
| response too large | `-32603` `"Response exceeds the server size limit"` | 200 |

Successful JSON responses: status 200, `Content-Type: application/json`. Handler errors use 200
because legacy SDK clients drop the JSON-RPC body on non-2xx statuses.

### 6.5 Pagination

Order is registration order (S-TOOLS deterministic order). A page is one response and must fit
`maxResponseBytes`; there is no adaptive paging. When tools, resources or prompts have large
descriptions or schemas, call `pageSize(n)` with a smaller `n`: a page over the limit is the
`-32603` size error (this repeats for every client that asks for that page). Cursor is
`EncodingUtil.base64Encode(Blob.valueOf('v1:' + offset))`. Invalid base64, wrong prefix, non-integer,
negative, or offset > size returns `-32602 "Invalid cursor"`. Offset equal to size returns an empty
page with no `nextCursor`. Page size default 50, `pageSize()` accepts 1 to 100.

### 6.6 Resource routing

`resources/read` checks the exact-URI map of static resources, then templates in registration order;
the first match wins. URIs longer than 2048 chars return `-32602`. Template matching is a linear scan
of literal segments; a variable matches one or more characters excluding `/ ? # &` and is
percent-decoded with `EncodingUtil.urlDecode(value, 'UTF-8')`. `request.variable(name)` returns the
decoded value. A template `read` returning `null` is "not found".

### 6.7 Completions

`ref/prompt` resolves by `name`; `ref/resource` resolves by exact `uriTemplate` (static resources
have no arguments and return empty values). The argument name must be declared (prompt argument or
template variable), else `-32602`. More than 100 values are cut to 100 with `hasMore: true` and
`total` set to the original count; the spec defines that shape, so this is not arbitrary truncation.

### 6.8 Size and heap guards

- `nodeLimit(bytes) = min(200,000, max(25,000, bytes / 8))` (32,768 at the default). Measured in the
  scratch org: walking about 45,000 nodes costs about 0.7 s CPU, roughly the cost of serializing them,
  which is why the node budget is tied to the byte limit instead of being fixed.
- Defaults: `maxRequestBytes` = `maxResponseBytes` = 262,144 (256 KiB). Both setters accept
  1,024 to 6,000,000 (the platform ceiling); a larger or smaller value throws
  `McpConfigurationException`. The effective request limit is `min(maxRequestBytes, remainingHeap / 8)`;
  the effective response limit is `min(maxResponseBytes, remainingHeap / 3)`. `remainingHeap` is
  `Limits.getLimitHeapSize() - Limits.getHeapSize()` read at request time.
- Request: step 3 above. The `/8` factor is a heuristic for `JSON.deserializeUntyped` expansion.
  Step 3a runs on the text, before the parser. The platform parser accepts thousands of nesting levels
  (verified: 2,500 levels parse in 0.15 s CPU), after which even `instanceof` on the result overflows the stack with an
  uncatchable `LimitException`, and 120,000 levels cost seconds of CPU. The guard counts `[` and `{` natively
  (about 2 ms at 256 KiB); only a text with more than 32 of them is scanned, one character at a time
  outside strings (about 4 microseconds each, 7 per escaped quote inside strings; measured worst cases at
  240,000 characters are 1.0 s of CPU for structure-only text and 1.1 s for escaped quotes; text that is mostly
  string content costs about 2 ms; a deep body stops after its 33rd bracket). Step 4a bounds what the parsed
  tree may cost every later stage and uses the same depth constant.
- Response, before serialization: one iterative bounded walk (no recursion; limits: depth 32, `nodeLimit(maxResponseBytes)`
  nodes, 10,000 entries per collection) over the **entire** result map, including `content`,
  `structuredContent`, `_meta` maps, annotations and icons, not only text blocks. It adds a lower
  bound of the serialized size per node (string length plus key length, a fixed 4 for number,
  boolean and null, base64 length for a `Blob`; an `SObject` is walked through `getPopulatedFieldsAsMap()`
  plus a fixed 128 for the `attributes` entry that `JSON.serialize` adds).
  A limit hit, an estimate above the effective response limit, or an estimate × 3 above remaining
  heap returns the size error before `JSON.serialize` runs. `McpToolResult.structured(...)` builds its
  JSON text block only after this check, and the estimate counts that block (structured × 2).
- Response, after serialization: `Blob.valueOf(json).size()` must be ≤ the effective response limit,
  otherwise return the size error. The same `Blob` is written to the response (one copy).
- **Supported result values** (`structured(...)`, `structuredContent(...)`, `meta(...)` on results,
  content, resource contents, tools, resources and prompts): `null`, `String`, `Boolean`, `Integer`, `Long`,
  `Decimal`, `Double`, `Date`, `Datetime`, `Time`, `Id`, `Blob`, `Map<String, X>` for any `X`, `List<X>` for any
  `X`, and `SObject` (populated fields only), including compound `System.Address` and `System.Location`.
  A top-level `structured(null)` or `structuredContent(null)` means no structuredContent field; nested nulls remain supported.
  Address text is counted with escape expansion and fixed field overhead; Location has a fixed coordinate budget.
  The walk does not copy or convert them, so numeric precision
  and nested `null` values reach the wire exactly as `JSON.serialize` writes them. **Deliberately
  refused**: `Set<T>`, `Map` with a non-`String` key (`Map<Id, X>`, `Map<Integer, X>`), enums, and custom
  Apex objects. Their size cannot be bounded without serializing them, so the walk throws
  `McpConfigurationException` before anything is serialized; the client gets `-32603` "Internal error" and the debug
  log names the fix: convert a `Set` to a `List`, a `Map<Id, X>` to a `Map<String, X>` and a custom object to a
  `Map<String, Object>`. On `tools/list` and the other list methods a refused `_meta` value fails the whole
  page. Handler-built data nested more than about 1,500 levels is not guarded: `instanceof` itself overflows
  the stack, and the framework cannot check before the first `instanceof`.
- Remaining blind spot: the lower bound can be far below the serialized size for text full of characters that
  JSON escapes (see `escapingGrowthIsCaughtAfterSerialization`); that case is caught only by the
  post-serialization step. The post step cannot prevent the heap use that
  `JSON.serialize` already caused.
- No output is truncated. These guards reduce, but do not remove, the chance of an uncatchable
  `LimitException` (also section 5.2); they say nothing about limits consumed by handler code.

## 7. stdio proxy contract (contract C3, npm)

The proxy stays a stdio MCP server that forwards each JSON-RPC message to the Apex endpoint over
HTTPS with Salesforce OAuth. It adds no public HTTP listener. It keeps zero runtime dependencies.

### 7.1 Inbound line handling

| Input line | Action |
| --- | --- |
| longer than 6 MiB (6,291,456 bytes) before newline | discard through the next newline, write `-32600` without id |
| not JSON | write `-32700` without id |
| JSON array | write `-32600 "Batch requests are not supported"` without id |
| object without `method`, with an `id` and a `result` or `error` (client response) | drop, debug log |
| any other object without `method` | write `-32600` |
| id that is not a string or a safe integer (`null`, fraction, boolean, array, object, unsafe integer) | write `-32600` without `id` |
| `notifications/cancelled` | local: abort the in-flight HTTP request for `params.requestId`, suppress its response, write nothing. Apex work already started still completes. |
| other notification | forward, write nothing for 2xx; log a warning for non-2xx |
| request whose id is already queued or in flight | write `-32600 "Duplicate request id"` **without `id`**, so a client cannot mistake it for the answer to the original request |
| request | enqueue for forwarding |

### 7.2 Outbound headers

Always: `Content-Type: application/json`, `Accept: application/json, text/event-stream`,
`Authorization: Bearer <token>`, `Content-Length`.

| Message | Extra headers |
| --- | --- |
| has `params._meta["io.modelcontextprotocol/protocolVersion"]` (modern) | `MCP-Protocol-Version: <that value>`, `Mcp-Method: <method>`; `Mcp-Name` for `tools/call`/`prompts/get` (`params.name`) and `resources/read` (`params.uri`) when that value is a string |
| `initialize` | none |
| other (legacy) | `MCP-Protocol-Version: <legacyVersion>` when known |

`legacyVersion` is process-scoped state set from the `result.protocolVersion` of a successful
`initialize` response (S-VERS: legacy semantics are scoped to the stdio process). Modern requests
never read it.

`Mcp-Name` encoding: plain when every char is 0x20 to 0x7E, no leading or trailing whitespace, and the
value does not match `^=\?base64\?.*\?=$`; otherwise `=?base64?<base64(utf8)>?=`. A malformed modern
`_meta` protocol version (not a string, empty, longer than 256 chars, or outside visible ASCII) is rejected
locally with `-32600` before any token is read. It is never treated as legacy. A `_meta` without the
version key stays legacy. A method longer than 256 chars or outside visible ASCII, and a `Mcp-Name`
source value longer than 2048 chars, are `-32600` as well.

### 7.3 Response handling

| Remote result | Output |
| --- | --- |
| 202 or 204 | nothing |
| 401 with `INVALID_SESSION_ID` | re-authenticate once, retry once. Concurrent 401s share one token request, and a 401 for an already replaced token retries without a new request. |
| any status, body is a JSON object with `jsonrpc: "2.0"`, exactly one of `result` or `error`, and an `error` with integer `code` and string `message` | validate with `JSON.parse`, then write the original text with only space, tab, CR and LF outside strings removed (`compactJson`), so the output is one line and number spelling (Long, Decimal, `1e999`, `-0`) is untouched. Never `JSON.stringify(JSON.parse(body))`, which corrupts large numbers. If the body `id` is present and differs from the request id in value or type (string vs number), write a local error instead. An error with a missing or null `id` gets the request id injected as the first member; the rest is copied verbatim. A result with a missing `id` is a local error. |
| 200 with empty body | local error |
| anything else (Salesforce error arrays, HTML, network error) | local error, status logged to stderr only |
| body larger than 8 MiB | abort, local error |
| no response within the request timeout (one deadline over authentication, retry and response) | abort, local error |

Local errors: `{"jsonrpc":"2.0","id":<request id or omitted>,"error":{"code":-32603,"message":"salesforce-mcp-lib proxy: <reason>","data":{"source":"salesforce-mcp-lib-proxy","httpStatus":<n or null>}}}`.
The `source` marker lets clients tell a proxy failure from a server error (S-BASIC local errors).
Remote bodies, tokens, and secrets never appear in local errors or logs.

### 7.4 Bounds and lifecycle

| Setting | Flag / env | Default | Allowed |
| --- | --- | --- | --- |
| request timeout | `--request-timeout-ms` / `SF_REQUEST_TIMEOUT_MS` | 120000 | 1000 to 600000 |
| concurrent HTTP requests | `--max-concurrency` / `SF_MAX_CONCURRENCY` | 4 | 1 to 25 |
| queued requests | constant | 64 | queue full: local error `-32603` |
| queued plus in-flight line bytes | constant | 64 MiB | over budget: request gets local `-32603`, notification is dropped with a warning |
| OAuth call deadline (token, refresh, code exchange) | constant (test seam only) | 30 s total, 1 MiB body cap | separate from the request timeout |
| instance URL and endpoint | config | https only, plain http for exact loopback (`localhost`, `[::1]`, `127.x.x.x`) | else exit 1 at startup |

On stdin end: stop reading, wait for in-flight and queued requests (each bounded by the timeout),
then exit 0. The current immediate `process.exit(0)` drops in-flight responses and is removed.

## 8. Cross-agent interface summary

| Contract | Producer | Consumer | Frozen items |
| --- | --- | --- | --- |
| C1 Apex API | Apex chunk | subscribers, examples, docs chunk | section 5 names and signatures |
| C2 HTTP wire | Apex chunk | npm chunk, direct HTTP clients | section 6.1 order, 6.2 tables, 6.3 shapes, 6.4 statuses |
| C3 stdio proxy | npm chunk | MCP clients, docs chunk | section 7 headers, outputs, flags |

The npm chunk tests against a mock that implements C2 statuses and bodies. It never imports Apex.
A change to a frozen item needs the parent's sign-off and an update to this document first.

## 9. Packaging and release

- `sfdx-project.json`: `versionNumber: "2.0.0.NEXT"`, same package id. `packages/salesforce-mcp-lib/package.json`: `2.0.0`.
- Package versions are created from the Dev Hub that owns `0HodL0000002PQXSA2`; the parent confirms
  which hub through the hub-query delegate. No hub alias is hardcoded in new scripts.
- Upgrade guidance (SF-UPG): removed classes are deleted or deprecated during upgrade
  (`--upgrade-type Mixed` default). `McpServer` keeps its name with a new API, so subscriber endpoints
  must be migrated in the same deployment window. Recommended: migrate in a sandbox, then install with
  `--upgrade-type Mixed --apex-compile package`, then deploy migrated endpoint code.
- Tag `v2.0.0-sf2.0.0-<build>` only after the real `04t` exists (CLAUDE.md release rules).
- `prepack: npm run build` in `package.json` so `npm pack` and `npm publish` never ship a stale `dist/`.

## 10. Risks to verify first (spike S0, scratch org)

1. `RestRequest.headers` contains `MCP-Protocol-Version`, `Mcp-Method`, `Mcp-Name`, `Origin`, and
   which casing the keys use.
2. Apex REST returns status 202 with an empty body, and 400/404/413 with the Apex-set JSON body intact.
3. `Accept: application/json, text/event-stream` does not trigger a platform 406.
4. `Limits.getLimitHeapSize()` value in the scratch org.

If item 1 fails, modern HTTP compliance is impossible on Apex REST; stop and report to the parent
before writing the header validation code.

## 11. Implementation notes from chunk A (2026-10-28)

Decisions taken while building the Apex core. They refine the sections above and change no frozen
contract item.

1. `ref/resource` completion references use the field `uri` (S-SCHEMA `ResourceTemplateReference`),
   not `uriTemplate`. It resolves by exact template string. A static resource uri returns an empty
   completion; any other value is `-32602`.
2. A JSON integer outside the `Long` range makes `JSON.deserializeUntyped` throw (verified in S0), so
   such a body, including a huge `id`, is `-32700`. An exponent form such as `1e400` parses as a
   `Decimal` and is rejected as an id by `McpWire.normalizeId` (`-32600`).
3. Header casing (S0): custom MCP headers arrive lower-cased, standard ones as sent. All reads go
   through one lower-cased map.
4. `McpRequest.forResource(String uri, Map<String,String> variables)` is added for template tests.
   `McpRequest.clientInfo()` and `clientCapabilities()` return an empty map, never null, when absent.
5. `McpToolResult.structured(null)` and `structuredContent(null)` mean "no structured content".
6. A tool with a builder `output(...)` schema whose non-error result has no `structuredContent` is
   `-32603`, like a mismatch. `skipOutputValidation()` disables both checks. Raw `outputSchema(Map)` is
   never validated.
7. Typed tool-argument getters return `null` for an absent or JSON `null` value and throw
   `McpException` for a wrong type. Lengths in `McpSchema` count UTF-16 code units.
8. Variable matching in templates is lazy: a variable ends at the first occurrence of the literal
   that follows it; the last variable ends at the last occurrence of the trailing literal. Invalid
   percent-encoding means no match.
9. Internal classes beyond the plan: `McpTestKit` (shared test helper, `@IsTest`) and `McpWireTest`.
   `McpRuntime` and `McpWire` expose `public` members only because Apex has no package-private scope.

## 12. Review fixes (2026-10-28, after chunk A)

Decided with the parent after the review of chunk A. Evidence and tests are in
`docs/superpowers/plans/2026-10-28-mcp-v2-apex-fixes.md`.

1. The request nesting guard runs on the raw text before `JSON.deserializeUntyped` (section 6.1 step 3a).
2. All wire comparisons are case-sensitive through `McpWire.same`; method names are checked against a
   case-sensitive set first (sections 5.4, 6.1).
3. `initialize` is legacy only when no version is named (section 6.1 step 8). An explicit modern version
   gets modern validation and then 404 `-32601`; an unknown version gets `-32022`.
4. Result values must be JSON-native; `Set`, non-`String` keys, enums and custom objects are refused before
   serialization; `SObject` is sized by its populated fields (section 6.8).
5. A tool without `input(...)` rejects any argument instead of only advertising a closed schema (section 5.3).
6. List pages are not adaptive: use a smaller `pageSize` for large items (section 6.5).

