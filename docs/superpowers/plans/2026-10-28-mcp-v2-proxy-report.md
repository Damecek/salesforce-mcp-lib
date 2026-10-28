# Chunk B report: npm proxy (C3)

Status: implemented, review fix wave applied. `npm test` 331/331 pass (baseline 132, 256 before the fix wave),
`npm run lint` and `npm run build` clean (`tsc --noEmit` exit 0, `tsc` exit 0).
Commands, run in `packages/salesforce-mcp-lib`: `npm test`, `npm run lint`, `npm run build`.
No git branch changes, commits, pushes or org writes. No new dependencies. The workspace was on
`feat/mcp-v2` (created by the Apex worker); untouched by this chunk.

## Files

| File | Change |
| --- | --- |
| `src/protocol.ts` (new) | `classifyLine`, `planHeaders`, `headersFromPlan`, `buildHeaders`, `encodeHeaderValue`, `interpretRemote`, `compactJson`, `localError`, `protocolError`, constants |
| `src/authHttp.ts` (new, fix wave) | shared bounded `postForm` for all OAuth calls: total deadline, body cap, socket destroy, https policy |
| `src/urlPolicy.ts`, `src/redact.ts` (new, fix wave) | https-or-exact-loopback policy; bounded, flattened remote text for errors |
| `src/mcpBridge.ts` | classified-message `forward(msg, signal)`, protocol headers, 8 MiB cap, one deadline over auth + retry + response, abort, `resolveTarget` token-safety checks, `legacyVersion` state, `reauthenticate(failedToken)` |
| `src/authStrategy.ts`, `src/oauth.ts`, `src/perUserAuth.ts` (fix wave) | single-flight acquisition and refresh, stale-401 detection, deadline and https policy through `authHttp.ts`, no remote bodies in errors |
| `src/stdio.ts` | `LineSplitter` (6 MiB, bytes), queue 64, 64 MiB byte budget, concurrency, in-flight/queued id map, cancellation, drain, output backpressure and closed-output shutdown; `startStdioListener(options)` returns a promise |
| `src/index.ts` | uses the new listener, flushes stdout, exits 0 after drain |
| `src/config.ts`, `src/types.ts` | `--request-timeout-ms` / `SF_REQUEST_TIMEOUT_MS` (1000..600000, default 120000), `--max-concurrency` / `SF_MAX_CONCURRENCY` (1..25, default 4), strict digits-only parsing, help text; also rejects credentials in `--instance-url` and a non-path `--endpoint` |
| `package.json` | `scripts.prepack = "npm run build"` only |
| `tests/protocol.test.ts` (new, 63), `mcpBridge.test.ts` (62), `stdio.test.ts` (51), `config.test.ts` (30), `authHttp.test.ts` (new, 24), `authStrategy.test.ts` (11), `npmConsumer.smoke.test.ts` (2 tests) | see below |

## Behaviour decisions (parent rulings applied)

- **Line splitting** works on bytes: UTF-8 split across chunks is safe, the limit is 6,291,456 bytes (a line of exactly that size is accepted), an oversize line yields one `-32600` and is discarded through the next newline. Invalid UTF-8 gives `-32700`.
- **Ids.** Only string or safe-integer ids are accepted. `null`, fractions, booleans, arrays, objects and unsafe integers give `-32600` without id. Queued and in-flight requests share one map keyed by `JSON.stringify(id)`, so `"1"` and `1` are distinct.
- **Parse errors vs client responses.** An object with no `method` is dropped as a client response only when it has an `id` and `result` or `error`. Anything else is `-32600`. Unparseable lines are always `-32700`.
- **Cancellation** works for queued requests (removed, never forwarded) and in-flight ones (HTTP aborted, response suppressed even if it arrives late). The cancelled id is released at once and can be reused.
- **Silence** (202/204/any status) is a notification-only success. A request answered with an empty 202/204/200 gets a local error with `httpStatus`. Notifications never write output, including on errors (warning log only).
- **Remote envelope validation.** Requires `jsonrpc: "2.0"`, exactly one of `result`/`error`, `error.code` integer and `error.message` string. The response id must equal the request id with type (string vs number). Mismatch gives a local error. A success keeps the strict id check. The body is validated with `JSON.parse` but never re-serialised (see M2 below).
- **Single timeout.** One deadline (`requestTimeoutMs`) covers `getAccessToken`, `reauthenticate`, the retry and the response, by racing the auth promises against the abort signal. The auth sockets themselves now have their own 30 s total deadline (M1).
- **Remote errors on 400/404** are forwarded unchanged (`-32022`, `-32601`, ...).
- **Token safety.** `resolveTarget` requires the endpoint to be a single-slash path on the instance origin, no credentials in the URL, https (plain http only for loopback, the existing test seam). No hostname allowlist, so custom Salesforce domains work. Node's `http.request` does not follow redirects, so a 3xx cannot carry the bearer token elsewhere (tested). Remote bodies, tokens and secrets never reach logs or local errors.
- `initialize` result `protocolVersion` is stored in the bridge instance and used as the legacy `MCP-Protocol-Version` for later non-modern messages.
- **Smoke test.** `npm pack` no longer uses `--ignore-scripts` and the build-if-missing step is gone, so `prepack` rebuilds `dist/`. The mock answers modern `server/discover` with a valid `DiscoverResult` and `notifications/initialized` with 202; stdout stays one line. The test closes stdin immediately, which also proves drain.

## Contract deviations and ambiguities (needs parent sign-off if disliked)

1. `interpretRemote(status, body, requestId)`: `requestId === undefined` means notification. Needed for the "202/204 only valid for notifications" ruling. Returns `silent` with an optional `warn`. A `write` outcome may carry `protocolVersion` (read from the validated parse, so `initialize` is not parsed twice).
2. `Bridge.forward` takes a classified message plus an `AbortSignal` and returns `{write|silent}`; it never rejects. `startStdioListener` takes an options object and returns a promise instead of calling `process.exit` itself.
3. A remote error with a missing or null id gets the request id injected (Apex omits ids on some errors). A result with a missing id is a local error. Parent approved: the HTTP exchange ties the error to the request.
4. **Changed in the fix wave.** A duplicate-id error is written without an id (M4). The spec 7.1 row "write -32600 Duplicate request id" is unchanged; only the id echo is gone.
5. **Changed in the fix wave.** A malformed modern `_meta` protocol version (non-string, empty, over 256 chars, not visible ASCII) is rejected locally with `-32600` and is never treated as legacy (M5). Spec 7.2 and 7.3 should say so.
6. Local errors for network failures use the reason "Could not reach the remote endpoint" (cause class in the stderr log only). The old behaviour of rejecting the promise is gone.
7. Config rejects a non-path `--endpoint`, credentials in `--instance-url`, and now a non-https `--instance-url` (exact loopback excepted) at startup (exit 1).
8. **New in the fix wave.** `AuthStrategy.reauthenticate(failedAccessToken?)` gained an optional argument. The bridge no longer calls `invalidateToken()` before re-authenticating. A method longer than 256 chars is `-32600 Invalid Request`. `Mcp-Name` source values over 2048 chars are `-32600`.
9. **New in the fix wave.** Spec 7.3 says "re-serialize with `JSON.stringify(JSON.parse(body))`". That corrupts Long and Decimal values, so the proxy emits the original token spelling (M2). The spec text needs the parent's update; the Apex worker area was not touched.

## Fix wave: decisions and tests

### H1 memory retention (stdio, protocol)

- `classifyLine` still parses once to classify, then drops the tree. A `RequestMessage` is now `{kind, id, method, headers, raw}` (notifications have no id). `headers` is a `HeaderPlan`: `modern` (version, already encoded `Mcp-Name`), `legacy` or `invalid` (reason). `params` is never retained.
- Header metadata is bounded: method, protocol version at most 256 chars, `Mcp-Name` source at most 2048 chars (encoded value stays under 8.3 KB). Over-long input is rejected with `-32600`, so a 6 MiB string cannot sit in the queue as "metadata".
- Aggregate budget `MAX_QUEUED_BYTES` = 64 MiB of line bytes across queued and in-flight messages (`maxQueuedBytes` option for tests), next to the 64 item cap. An over-budget request gets a local `-32603` "Too many queued request bytes"; an over-budget notification is dropped with a warning.
- Release is exact and idempotent per item: queued cancel releases at once, an in-flight cancel releases when its exchange unwinds (the raw line is still referenced until then), completion, rejected forward and local error all release in `run()`'s `finally`. Rejected admissions never add bytes.
- Debug logging no longer calls `JSON.parse`. Before, `summarise()` ran on every inbound line and every response even with debug off (the template string was always evaluated). Now the log text comes from the classification (id, method, byte count) and the response length.
- Tests: `protocol.test.ts` "classifyLine retention" (exact key set, no `params`, 100k-element params tree not retained, long method rejected); `stdio.test.ts` "byte budget" (7 tests: over budget, notification drop, release on completion, exact release on double cancel of a queued item, in-flight cancel, rejected forward, one `JSON.parse` per line). No gigabyte test; budgets are tiny and assertions are structural.

### H2 parallel 401 and refresh rotation (authStrategy, oauth, mcpBridge)

- `PerUserAuthStrategy` has one `inflight` promise shared by `getAccessToken` and `reauthenticate`, so a rotating refresh token is redeemed by one request at a time. Interactive login shares it too.
- `reauthenticate(failedAccessToken)`: if the cached token is non-null and differs from the failed one, the 401 is stale and the current response is returned without any request and without touching stored tokens. If the cached token is the failed one it is dropped, so callers that start during the refresh wait for it instead of reusing the rejected token.
- Only the single flight deletes stored tokens (on `invalid_grant`), so a stale failure cannot wipe newly issued ones. A failed flight clears `inflight`, so the next call can retry.
- `ClientCredentialsStrategy` has the same single flight and stale check (instance-level `current` response next to the module token cache).
- The bridge passes the token it sent and no longer calls `invalidateToken()` (kept on `PerUserAuthStrategy`, now token-conditional).
- Tests: `mcpBridge.test.ts` four concurrent 401s with client credentials (2 token requests, not 5 or 8), late 401 adds none; four concurrent 401s with a mock token endpoint that honours one-time refresh tokens (1 redemption, 0 rejected, `A2/R2` still on disk, late 401 changes nothing); `authStrategy.test.ts` initial acquisition, mixed `getAccessToken`/`reauthenticate`, reauth-starts-refresh, stale failure, `invalid_grant` handled once, `SessionExpiredError` for reauth, failed flight not poisoned, login coalesced. Mutation check: removing the coalescing or the stale check fails 2 to 6 tests.

### M1 real auth deadline and cancellation (authHttp, bridge)

- `authHttp.postForm` replaces the two duplicated `postForm` functions. One total timer (default 30 s, `authTimeoutMs` config seam, no CLI flag) covers connect, headers and body, so a slow trickle cannot extend it. On timeout, oversize body (1 MiB, declared or streamed), network error or premature close it destroys the request and socket and settles once. `agent: false` and `Connection: close` leave no pooled socket.
- Single-flight waiters: the shared auth request has its own deadline and is not tied to any request's signal. `raceAbort` only stops that waiter from waiting. Cancelling one request leaves the others and the one token request alone.
- Tests (`authHttp.test.ts`): stalled endpoint closes at the deadline with exactly one connection and no later attempt; slow trickle ends at the total deadline; declared and chunked oversize bodies close the socket; mid-body drop; a real child Node process exits by itself after a stalled call (no dangling handle); `authenticate`, `refreshAccessToken`, `exchangeCodeForTokens` honour the options; bridge test cancels one of two waiters and the other succeeds with one token request.

### M2 lossless remote bodies (protocol)

- After `JSON.parse` validation, `compactJson` removes only space, tab, CR and LF outside strings with a small state machine (string and backslash-escape aware). Number spelling, escapes and string content are untouched.
- Id injection for an error with a missing or null id: `withId` scans the compact text for top-level members, drops every top-level `id` member (null, escaped key like `"\u0069d"`, duplicates) and emits `{"id":<request id>,` followed by the other members copied verbatim. `error.data` is never re-serialised. The id moves to the front of the line.
- Tests: `12345678901234567890`, `0.1000000000000000055511151231257827`, `1e999`, `1.0`, `-0`, `1E+2` verbatim in single-line and multi-line (LF, CRLF, tabs) bodies; whitespace, `\n`, `\"`, `\\`, `\uXXXX`, surrogate pairs and raw unicode inside strings; trailing backslashes; id injection with numbers in `error.data`; escaped and duplicate `id` keys; bridge-level multi-line body.

### M3 output backpressure and closed output (stdio, index)

- When `output.write` returns false the listener sets `blocked`, pauses input and starts no new forward. Already running forwards may still write, so the backlog is at most `maxConcurrency` responses (each 8 MiB at most). Split lines that were not handled yet stay in an event list instead of being written as a run of errors. On `drain` it resumes: events, then the queue, then input.
- On output `error`, `close`, a failed write callback or a throwing `write`: abort every in-flight controller, release and drop the queue, clear the id map, stop reading stdin and resolve the promise. Later writes are no-ops and extra errors are ignored (the error listener stays attached, so no `EPIPE` crash).
- `index.ts` flushes stdout with a 5 s cap and a try/catch, so a closed or stalled pipe cannot hang or crash the exit.
- Tests: pause and resume on drain, rest-of-chunk held, bounded writes while blocked, settle after drain when stdin ended, EPIPE error, close event, failing callback, throwing write, repeated errors.

### M4 and M5 (stdio, protocol, bridge)

- M4: `Duplicate request id` has no `id`, so a client cannot resolve the original request with it.
- M5: header-invalid method or version gives `-32600` with the request id and no `data` marker, before any token is read (no auth traffic). Notifications stay silent with a warning. A `_meta` that has the protocol-version key with a bad value is rejected, never legacy; a `_meta` without the key (or a non-object `_meta`) stays legacy.

### M6 transport policy and redaction (urlPolicy, config, authHttp, bridge)

- One rule in `urlPolicy.ts`: https, or plain http to `localhost`, `[::1]` or `127.x.x.x` exactly (so `localhost.evil.com` and `127.0.0.1.evil.com` fail). No Salesforce hostname allowlist.
- Enforced in config parsing (server and login; the URL is never echoed, also for unparseable input), in `postForm` before a socket exists (covers client credentials, code exchange and refresh, so `client_secret` and refresh tokens cannot go out over http), and in `resolveTarget` for the bearer token.
- Redaction: OAuth errors no longer include the first 200 chars of a bad response body; `error_description` and `error` are flattened to printable ASCII and cut at 200 chars. The bridge logs auth failures through `describeError` (our own bounded auth messages, otherwise only the class name) and network failures by error code. Method names in logs are flattened and cut at 64 chars.
- Tests: `authHttp.test.ts` five non-loopback URL forms for `authenticate` and `refreshAccessToken`, code exchange, a stored refresh token with a non-https instance (zero `http.request`/`https.request` calls, secrets absent from messages), loopback `127.0.0.1` and `localhost` mocks still work; `config.test.ts` rejection without echo, https custom domains and loopback accepted; redaction tests.

## Residual risks

- Classification still parses a line once, so a 6 MiB structure-heavy line allocates its tree (about 20x) transiently, one at a time because `JSON.parse` is synchronous. Nothing from that tree is retained. The 64 MiB budget counts UTF-8 line bytes; a line with non-Latin-1 text can occupy up to twice that as a JS string, so worst-case retained raw text is about 128 MiB, plus up to 8 MiB per concurrent response (max 25).
- A client that keeps stdout open but stops reading blocks the proxy. There is no drain deadline: in-flight forwards still end by the request timeout, queued ones wait. A closed pipe is handled.
- The 30 s auth deadline is a constant (config seam only). A failed refresh leaves no cached token, so each later request starts its own sequential attempt, one at a time and each bounded by 30 s. The interactive login flow has no deadline of its own beyond the callback server's.
- Log redaction in `index.ts` uses the secrets known at startup. Tokens issued by a later refresh are not added to that list; the auth code never logs them, and remote text in errors is bounded and flattened.
- A response id such as `1.0` equals request id `1` after parsing and is emitted verbatim.
- A `reauthenticate` that returns an `instance_url` on another origin is accepted (https required). Intentional, no allowlist.
- `ClientCredentialsStrategy` still shares its token through a module-level cache (unchanged).
- Not done, outside the allowed files: spec 7.1, 7.2 and 7.3 wording (items 4, 5 and 9 above) and the two READMEs (`--instance-url` must now be https except loopback). OCR delegation review was not run (the task forbids subagents); the parent reviews.
