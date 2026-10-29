# Sales meeting preparation demo (synthetic)

Date: 2026-10-29. Sandbox `carvago-dev` only. Source: `dev/mcp-sales-demo/force-app/main/default/classes/`. Endpoint: `/services/apexrest/mcp/sales-demo`.
No framework, npm or release change. The demo is committed as a standalone example under `dev/mcp-sales-demo/`. Its only dependency is the installed MCP v2 framework package.

## Data disclaimer

Every account, opportunity, name, amount, date and owner is invented and held in constants (`SalesDemoData`). The server runs no SOQL, no DML
and no callouts and sends nothing. The as-of date is fixed at 2026-10-29, so results do not change from day to day. "Demo AE Alex Morgan" and
the like are not real people. The risk rules are a small fixed rule set, not a forecast model and not a claim about any real CRM.

## Business story

An account executive opens a customer meeting in an hour. The assistant needs four things: which account, what is in the pipeline, which deal is
in trouble and why, and a draft follow-up. The server exposes exactly those steps.

| Step | Tool | What it does |
| --- | --- | --- |
| 1 | `sales_demo_find_accounts` | Search by text, segment, region, open-pipeline flag. Bounded page (limit 1 to 5, offset 0 to 100) with `nextOffset`. |
| 2 | `sales_demo_get_account_brief` | One account, its pipeline total in the account currency, and its opportunities (open by default) sorted by close date, each with a risk level. |
| 3 | `sales_demo_review_opportunity` | Scores one open opportunity with five rules. Returns factors with evidence and prioritized next steps. |
| 4 | `sales_demo_draft_follow_up` | Drafts an email or a meeting agenda (agenda minutes add up to the meeting length). Draft only. |

All four tools carry `readOnlyHint: true`, `destructiveHint: false`, `idempotentHint: true`, `openWorldHint: false`. That is accurate: they compute from
constants and return text. A real "send email" or "create task" tool would be a separate tool with different hints.

## Synthetic data

| Account id | Segment, region, currency | Open pipeline | Open opportunities (risk) |
| --- | --- | --- | --- |
| `demo-account-northstar` | enterprise, dach, EUR | 325000 | fleet-renewal 240000 (low), telematics-pilot 85000 (high) |
| `demo-account-bluepeak` | mid_market, czsk, CZK | 2450000 | depot-expansion 1800000 (low), support-upgrade 650000 (high) |
| `demo-account-cedarline` | smb, pl, PLN | 42000 | starter-plan 42000 (medium); onboarding 18000 is closed_won |
| `demo-account-harborview` | enterprise, dach, EUR | 440000 | multisite 410000 (medium), training 30000 (low) |
| `demo-account-lumen` | mid_market, czsk, CZK | 0 | none; pilot is closed_lost |

Totals never mix currencies. Risk rules (version `sales-demo-rules-1`, also in the playbook resource): overdue close date 3, close within 14 days while still
in prospecting or qualification 2, last activity 14 to 29 days ago 2 (30 or more 3), no decision maker 2, no next step 1. High at 5 or more, medium at 3 or 4, low below 3.

## MCP features used

| Feature | Where |
| --- | --- |
| Fluent nested input schema, enums, required, bounds, `additionalProperties: false` | find (`filters`, `page`), draft (`meeting.attendees` array, `durationMinutes` 15 to 90) |
| Output schema and `structuredContent`, validated by the framework before sending | all four tools |
| Text fallback | find, brief, review: framework-generated JSON text. Draft: the human-readable draft as text, schema-conformant `structuredContent` beside it |
| Tool annotations | all four (see above) |
| Resource links in tool results | account and opportunity links in find, brief, review, draft |
| Static resource | `demo-sales://playbook` (markdown, audience user and assistant, priority 0.8) |
| Resource templates | `demo-sales://accounts/{accountId}`, `demo-sales://opportunities/{opportunityId}` (unknown id gives `-32602` "Resource not found") |
| Prompt with required and optional argument | `prepare_account_meeting` (`accountId` required, `goal` optional) returns a text instruction, the embedded playbook and a resource link |
| Completion | prompt `accountId` and `goal`, template `accountId` and `opportunityId` |
| Pagination | `pageSize(2)`: `tools/list` returns two pages of two tools with `nextCursor` |
| Tool errors visible to the user | unknown ids, closed opportunity, schema violations return `isError: true` with a readable message |
| Size cap | framework default 262144 bytes unchanged. Largest live response: 5166 bytes |

Not used on purpose: images, audio, icons, `_meta` on tools, sampling, elicitation, tasks. None of them serves this business case.

## The complete server definition

`SalesDemoEndpoint.build()` is the whole registration (`dev/mcp-sales-demo/force-app/main/default/classes/SalesDemoEndpoint.cls`):

```apex
/**
 * SYNTHETIC sales meeting preparation demo (account 360 and opportunity follow-up) at /mcp/sales-demo.
 * Reads and writes no records. Page size 2 makes tools/list span two pages.
 */
@RestResource(urlMapping='/mcp/sales-demo')
global with sharing class SalesDemoEndpoint {
    @HttpPost
    global static void post() {
        build().handle(RestContext.request, RestContext.response);
    }

    public static McpServer build() {
        return new McpServer('sales-meeting-demo', '1.0.0')
            .title('Sales meeting preparation (synthetic demo)')
            .description('Account 360 and opportunity follow-up over invented data. No Salesforce records are read or written.')
            .instructions('All data is synthetic. Start with sales_demo_find_accounts, then sales_demo_get_account_brief, sales_demo_review_opportunity and sales_demo_draft_follow_up. Drafts are never sent.')
            .tool(new SalesDemoFindAccountsTool())
            .tool(new SalesDemoAccountBriefTool())
            .tool(new SalesDemoReviewOpportunityTool())
            .tool(new SalesDemoDraftFollowUpTool())
            .resource(new SalesDemoPlaybookResource())
            .resourceTemplate(new SalesDemoAccountTemplate())
            .resourceTemplate(new SalesDemoOpportunityTemplate())
            .prompt(new SalesDemoMeetingPrompt())
            .pageSize(2);
    }
}
```

## Sample scenario

Scenario: prepare for a Northstar meeting. Calls are real responses from the sandbox (sanitized: no token, no host). Each also carries `resultType`, `_meta.serverInfo`
and the JSON text fallback, omitted below.

`tools/call sales_demo_get_account_brief` with `{"accountId":"demo-account-northstar"}` returns this `structuredContent`:

```json
{"account":{"accountId":"demo-account-northstar","name":"Northstar Mobility (demo)","segment":"enterprise","region":"dach","currency":"EUR","industry":"Fleet leasing","owner":"Demo AE Alex Morgan"},
 "summary":{"openOpportunityCount":2,"openPipeline":325000,"highRiskCount":1,"nextCloseDate":"2026-11-05"},
 "opportunities":[
  {"opportunityId":"demo-opp-northstar-telematics-pilot","name":"Telematics pilot, 40 vehicles","stage":"proposal","amount":85000,"currency":"EUR","closeDate":"2026-11-05","daysToClose":7,"lastActivityDate":"2026-10-09","daysSinceActivity":20,"riskLevel":"high","riskScore":5},
  {"opportunityId":"demo-opp-northstar-fleet-renewal","name":"Fleet contract renewal 2027","stage":"negotiation","amount":240000,"currency":"EUR","closeDate":"2026-11-20","daysToClose":22,"lastActivityDate":"2026-10-27","daysSinceActivity":2,"riskLevel":"low","riskScore":0}],
 "asOf":"2026-10-29","demoData":true}
```

`sales_demo_review_opportunity` with `{"opportunityId":"demo-opp-bluepeak-support-upgrade"}` returns risk 7, high:

```json
{"riskScore":7,"riskLevel":"high","rulesVersion":"sales-demo-rules-1",
 "factors":[
  {"rule":"overdue_close_date","points":3,"evidence":"Close date 2026-10-20 passed 9 days before 2026-10-29"},
  {"rule":"stale_activity","points":3,"evidence":"Last activity 35 days ago (30 or more)"},
  {"rule":"no_next_step","points":1,"evidence":"No next step is scheduled"}],
 "nextSteps":[
  {"priority":1,"rule":"overdue_close_date","action":"Agree a revised close date with the buyer and update the opportunity"},
  {"priority":2,"rule":"stale_activity","action":"Re-engage this week with a short check-in call"},
  {"priority":3,"rule":"no_next_step","action":"Book the next meeting or milestone with a date"}]}
```

`sales_demo_draft_follow_up` with `{"opportunityId":"demo-opp-northstar-telematics-pilot","channel":"meeting_agenda","meeting":{"durationMinutes":45,"attendees":["Dana (demo buyer)"]}}` returns this text
(`structuredContent` has `mode: "draft_only"`, `sent: false`, `basedOnRules: ["stale_activity","no_decision_maker","no_next_step"]`):

```text
DRAFT (synthetic demo, not sent)
Meeting with Northstar Mobility (demo), 45 minutes
Attendees: Dana (demo buyer)
1. Recap and goals (9 min)
2. Catch up, as our last contact was 20 days ago (9 min)
3. Meet the person who approves this decision (9 min)
4. Set a date for the next step (9 min)
5. Agree owners and dates (9 min)
```

`sales_demo_find_accounts` with `{"page":{"offset":3}}` returns the last two accounts: `total: 5`, `nextOffset: null`.
`tools/list` page 1 returns `sales_demo_find_accounts`, `sales_demo_get_account_brief` and `nextCursor: "djE6Mg=="`; page 2 returns the other two tools and no cursor.

Intentional mistakes (all HTTP 200):

| Call | Result |
| --- | --- |
| brief with `demo-account-nope` | `isError: true`: `Unknown demo account "demo-account-nope". Call sales_demo_find_accounts to list valid accountId values.` |
| review `demo-opp-cedarline-onboarding` | `isError: true`: `Opportunity "demo-opp-cedarline-onboarding" is closed_won. Only open opportunities can be reviewed.` |
| find with `page.limit` 6 | `isError: true`: `arguments.page.limit: must be at most 5` |
| draft with `channel: "sms"` and `extra: 1` | `isError: true`: `arguments.channel: must be one of email, meeting_agenda` and `arguments.extra: is not allowed` |
| `resources/read demo-sales://accounts/demo-account-nope` | JSON-RPC `-32602` "Resource not found" |
| `prompts/get` with `goal: "world_domination"` | JSON-RPC `-32602` `Unknown goal "world_domination". Use one of: renewal_review, pipeline_risk_review, expansion_discovery, executive_alignment` |

Completion: `accountId` with prefix `demo-account-` returns all 5 ids (`total` 5, `hasMore` false). `goal` with prefix `e` returns `["expansion_discovery","executive_alignment"]`.
Template `opportunityId` with prefix `demo-opp-n` returns the two Northstar opportunities.

## Evidence

| Item | Result |
| --- | --- |
| Deploy | `0AfAP00000bhMWD0A2`, `RunSpecifiedTests` with `SalesDemoEndpointTest`, 12 of 12 components, 9 of 9 tests passed |
| Coverage (lines) | every `SalesDemo*` production class 87 percent or higher (`SalesDemoEndpoint` and `SalesDemoAccountTemplate` 14 of 16, the rest higher) |
| Collision check | before the deploy no `SalesDemo*` class existed in the sandbox. `/mcp/records`, `/mcp/minimal`, `/mcp/e2e`, `/mcp/harness`, `/mcp/demo` were not touched |
| Tests assert | pagination walk, filters, totals, sorted opportunities, risk points add up, agenda minutes add up, tool errors, resources, templates, prompt, completion, no SOQL, DML or callouts, heap under 500000 bytes, CPU under 3000 ms, response under 262144 bytes |
| Live HTTP | 25 calls, all HTTP 200, 5166 bytes largest. Every call in the list above was made |
| Stdio | published `salesforce-mcp-lib@2.0.0` through a private launcher: `initialize` (waited), `initialized`, `tools/list` over 2 pages (4 tools), `tools/call` brief and an unknown-opportunity tool error |

Authentication in the live run is an `sf` session token held in process. It is not evidence for OAuth login or refresh.

One implementation note: `List.add(0, x)` on an empty Apex list throws `ListException`, which the framework reports as "Internal error". The first deploy hit this,
the fix is in `SalesDemoData.oppsFor`.

## Client limits

The Codex MCP client used for the native demo (project entry `carvago_sales_demo`, tools limited to the four names above) exposes tools only.
Prompts, completion, resources and templates are not surfaced as native features there, so they are verified over live HTTP (above) and Apex tests, not through the agent UI.

## Reproduce

```bash
sf project deploy start --target-org <sandbox> --source-dir dev/mcp-sales-demo/force-app \
  --test-level RunSpecifiedTests --tests SalesDemoEndpointTest
```

Then `POST` JSON-RPC to `<instance>/services/apexrest/mcp/sales-demo` with `Authorization: Bearer <token>`, `Content-Type: application/json` and the MCP routing headers described in `docs/mcp-wire-contract-2026-07-28.md`.

## Production adaptation

This demo has no data access by design. To use the pattern on real data:

1. Replace the constant lookups in `SalesDemoData` with queries using `Database.query(..., AccessLevel.USER_MODE)` so sharing and field-level security apply to the calling user. Keep classes `with sharing`.
2. Bind every user-controlled value (`query`, ids) with bind variables, keep `LIMIT` at the tool page size, and keep the page bounds in the input schema.
3. Keep read tools and write tools separate. A tool that sends email or creates a task needs `readOnly(false)`, an honest `destructive` and `idempotent` value, and an explicit user confirmation in the client.
4. Use real Salesforce Ids and validate them (`Id.valueOf` in a try block) instead of the `demo-` ids.
5. Replace the rule set with the business's own rules, or call an approved scoring service. Keep each factor's evidence in the output so the user can check it.
6. Run the same Apex tests against test data created in the test, and keep the no-callout, heap and CPU assertions.

## Parameter semantics

`tone` affects only email greeting and sign-off. `meeting.attendees` and `durationMinutes` apply only
to meeting agendas. `nextCloseDate` is the earliest close date of an open opportunity and may be overdue.
The prompt's `goal` changes the assistant instruction, not a server-side tool execution workflow.

## Post-review validation

Deploy `0AfAP00000bhN2T0AU` succeeded in carvago-dev after parameter descriptions and bounded
prompt-error text were updated. All 12 components and 10 Apex tests passed, including the new
oversized prompt error regression. Initial live HTTP evidence remains the separate 25-call run.
