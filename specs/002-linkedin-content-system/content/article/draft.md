# Building an MCP Server Inside Salesforce — Zero Dependencies, Full Protocol, Native Apex

*How we implemented the Model Context Protocol natively in Apex so AI agents can talk to Salesforce without middleware, without data extraction, and without a single external dependency.*

**Word count**: 2180
**Claims referenced**: C-001, C-002, C-003, C-004, C-005, C-006, C-007, C-008, C-009, C-010, C-011, C-012, C-013, C-014, C-015, C-016, C-017, C-018, C-019, C-020, C-021, C-022
**Repo**: https://github.com/damecek/salesforce-mcp-lib

---

## TL;DR

- Salesforce MCP Library is an open-source framework that implements the full MCP 2025-11-25 specification natively in Apex — all 11 protocol methods, wire-format verified, zero external dependencies
- The architecture uses two layers: a stateless Apex server (54 classes) paired with a stateful TypeScript stdio proxy (6 modules, zero npm production dependencies)
- A working MCP endpoint takes 12 lines of Apex; the framework handles JSON-RPC dispatch, capability advertisement, and error translation
- AI agents inherit your org's existing four-layer security model — OAuth scopes, Profiles, Permission Sets, Sharing Rules — with zero new infrastructure

---

## The Problem — Why Every AI-to-Salesforce Integration Looks the Same

If your team has connected an AI agent to Salesforce, the architecture probably looks familiar: a custom REST endpoint, a middleware layer that holds credentials, and some combination of data extraction and transformation before anything reaches the model.

It works. And then it stops working.

The first endpoint is straightforward. The second is a copy-paste job. By the tenth, you have a collection of bespoke integrations that nobody fully owns — each with its own authentication setup, its own error handling, and its own documentation that goes stale the moment a field name changes. Credentials are scattered across systems. Data leaves your security perimeter on every request. And no AI agent can ask any of these endpoints "what tools do you offer?" — capabilities are invisible without someone maintaining a manual mapping.

The real cost isn't building the first integration. It's maintaining the 47th, when three teams are adding tools and nobody owns the integration layer. Every custom endpoint is a maintenance line item your team carries indefinitely.

There's a protocol designed to solve exactly this problem.

## What MCP Is — And Why It Matters for Salesforce

The [Model Context Protocol](https://modelcontextprotocol.io) (MCP) is an open standard that defines how AI agents discover and invoke external capabilities. Think of it as USB-C for AI integrations: one standard interface, any agent, any capability provider.

MCP defines three capability types:

- **Tools** — executable actions an agent can invoke (query records, create cases, run calculations)
- **Resources** — read-only data endpoints addressed by URI (org metadata, configuration, reference data)
- **Prompts** — reusable prompt templates with typed arguments (record summaries, analysis templates)

The protocol runs over JSON-RPC 2.0. An agent connects, sends an `initialize` request, discovers available capabilities through `tools/list`, `resources/list`, and `prompts/list`, then invokes them through `tools/call`, `resources/read`, and `prompts/get`. The server advertises only what it has — no static capability manifests to maintain.

[Salesforce MCP Library](https://github.com/damecek/salesforce-mcp-lib) implements the full MCP 2025-11-25 specification in native Apex. All [11 protocol methods](https://github.com/damecek/salesforce-mcp-lib/blob/main/docs/mcp-wire-contract-audit-2025-11-25.md) are implemented and wire-format verified against the spec in dedicated test classes. The framework also supports backward-compatible version negotiation across four protocol versions (2025-11-25, 2025-06-18, 2025-03-26, 2024-11-05), so clients running older MCP versions can connect without friction.

## Architecture — Two Layers, Zero Dependencies

The design splits into two layers that complement each other:

**Layer 1: Stateless Apex Server.** Salesforce `@RestResource` endpoints are synchronous and stateless — there's no cross-request memory, no persistent session objects. Rather than fighting this constraint, the framework leans into it. The [McpServer](https://github.com/damecek/salesforce-mcp-lib/blob/main/force-app/main/mcp/classes/McpServer.cls) rebuilds its handler chain on every request. Subscribers register capabilities inline, call `handleRequest()`, and the framework dispatches through a configured [JSON-RPC module](https://github.com/damecek/salesforce-mcp-lib/blob/main/force-app/main/mcp/classes/McpJsonRpcModuleBuilder.cls). No persistent state means no session cleanup, no state-related bugs, no cross-request leakage.

**Layer 2: Stateful TypeScript Proxy.** The [stdio proxy](https://github.com/damecek/salesforce-mcp-lib/blob/main/packages/salesforce-mcp-lib/src/mcpBridge.ts) owns everything the Apex layer can't: OAuth tokens, session lifecycle, and transport bridging. It authenticates via OAuth 2.0 client credentials at startup, caches the token, and transparently re-authenticates on `INVALID_SESSION_ID`:

```typescript
// 401 — attempt single re-auth then retry.
if (first.status === 401 && isInvalidSession(first.body)) {
  log.warn('Received INVALID_SESSION_ID (HTTP 401) — attempting re-authentication');
  const newAuth = await authenticate(config);
  log.warn('Re-authentication successful — retrying original request');
  const retry = await postJsonRpc(newAuth.instance_url, config.endpoint, newAuth.access_token, message);
}
```

The JSON-RPC 2.0 core is implemented entirely in-repo — [14 Apex classes](https://github.com/damecek/salesforce-mcp-lib/blob/main/force-app/main/json-rpc/classes/JsonRpcServiceRuntime.cls) covering the full specification, including all five standard error codes and batch request support. On top of that, 40 MCP classes handle protocol negotiation, capability dispatch, and response serialization.

The critical design decision: **zero external production dependencies on both sides**. The Apex layer uses only platform-native APIs — `JSON.deserializeUntyped()` for parsing, standard Apex collections for data structures. The TypeScript proxy uses only Node.js built-in modules — `node:https`, `node:http`, `node:readline`, `node:url`. No npm packages. No managed Apex libraries. Nothing to audit beyond the [one repository](https://github.com/damecek/salesforce-mcp-lib).

## Developer Experience — Four Abstract Classes and 12 Lines to a Working Endpoint

The framework surface is deliberately small. A complete MCP endpoint requires two Apex classes: one `@RestResource` endpoint and one capability definition.

Here's the endpoint — [12 lines of Apex](https://github.com/damecek/salesforce-mcp-lib/blob/main/examples/minimal/force-app/main/default/classes/MinimalMcpEndpoint.cls):

```apex
@RestResource(urlMapping='/mcp/minimal')
global class MinimalMcpEndpoint {
    @HttpPost
    global static void handlePost() {
        McpServer server = new McpServer();
        server.registerTool(new MinimalTool());
        server.handleRequest(RestContext.request, RestContext.response);
    }
}
```

And here's the tool — extending [`McpToolDefinition`](https://github.com/damecek/salesforce-mcp-lib/blob/main/force-app/main/mcp/classes/McpToolDefinition.cls) requires implementing three methods:

```apex
public class MinimalTool extends McpToolDefinition {
    public MinimalTool() {
        this.name = 'echo';
        this.description = 'Echoes the provided message back to the caller';
    }
    public override Map<String, Object> inputSchema() {
        return new Map<String, Object>{
            'type' => 'object',
            'properties' => new Map<String, Object>{
                'message' => new Map<String, Object>{
                    'type' => 'string', 'description' => 'The message to echo'
                }
            },
            'required' => new List<String>{ 'message' }
        };
    }
    public override void validate(Map<String, Object> arguments) {
        if (!arguments.containsKey('message')) {
            throw new McpInvalidParamsException('message is required');
        }
    }
    public override McpToolResult execute(Map<String, Object> arguments) {
        String msg = (String) arguments.get('message');
        McpToolResult result = new McpToolResult();
        result.content = new List<McpTextContent>{ new McpTextContent(msg) };
        return result;
    }
}
```

For a production-like example, the [ExampleQueryTool](https://github.com/damecek/salesforce-mcp-lib/blob/main/examples/e2e-http-endpoint/force-app/main/default/classes/ExampleQueryTool.cls) runs actual SOQL against Account records:

```apex
public override McpToolResult execute(Map<String, Object> arguments) {
    String term = (String) arguments.get('searchTerm');
    List<Account> accounts = [SELECT Id, Name, Industry FROM Account
                              WHERE Name LIKE :('%' + term + '%') LIMIT 10];
    McpToolResult result = new McpToolResult();
    result.content = new List<McpTextContent>{ new McpTextContent(JSON.serialize(accounts)) };
    return result;
}
```

The [E2E endpoint](https://github.com/damecek/salesforce-mcp-lib/blob/main/examples/e2e-http-endpoint/force-app/main/default/classes/E2eHttpEndpoint.cls) shows all three capability types registered together — a SOQL query tool, an org metadata resource, and a record summarization prompt — in a single 14-line class.

Registration is explicit and programmatic: `registerTool()`, `registerResource()`, `registerPrompt()`. No annotation scanning, no auto-discovery — the endpoint declares exactly what it exposes. The [initialize handler](https://github.com/damecek/salesforce-mcp-lib/blob/main/force-app/main/mcp/classes/McpInitializeHandler.cls) dynamically advertises only the capability categories that have registered definitions, so agents never see empty capability sets.

## Security — Four Layers You Already Have

Most AI integration frameworks hand you a tool executor and leave authorization as an exercise for the reader. The [Salesforce MCP Library](https://github.com/damecek/salesforce-mcp-lib/blob/main/docs/mcp-authorization-feasibility-report-2026-03-22.md) takes the opposite approach: your org's existing security model applies automatically.

The framework inherits a four-layer authorization model:

| Layer | Enforcement | Mechanism |
|---|---|---|
| API Access | Salesforce Platform | Connected App OAuth scopes |
| Object/Field Access | Salesforce Platform | Profile + Permission Sets |
| Record Access | Salesforce Platform | OWD + Sharing Rules |
| Tool Authorization | Subscriber Code | Custom logic in `validate()`/`execute()` |

Three of these four layers are enforced by the Salesforce platform itself. You don't build them, configure them in the framework, or maintain them separately. Whatever Profiles, Permission Sets, and Sharing Rules you've already configured for your users apply identically to AI agent requests.

On the proxy side, security is enforced at the infrastructure level. The [startup code](https://github.com/damecek/salesforce-mcp-lib/blob/main/packages/salesforce-mcp-lib/src/index.ts) wraps every logger with automatic secret redaction — the `client_secret` is replaced with `"****"` before any message reaches stderr:

```typescript
const secrets = [config.clientSecret];
const logger = {
  debug: (msg: string) => rawLogger.debug(redactSecrets(msg, secrets)),
  info:  (msg: string) => rawLogger.info(redactSecrets(msg, secrets)),
  warn:  (msg: string) => rawLogger.warn(redactSecrets(msg, secrets)),
  error: (msg: string) => rawLogger.error(redactSecrets(msg, secrets)),
};
```

Raw Salesforce error bodies — stack traces, org identifiers, `APEX_ERROR` messages — are [never exposed](https://github.com/damecek/salesforce-mcp-lib/blob/main/packages/salesforce-mcp-lib/src/mcpBridge.ts) to the MCP client. The proxy returns generic JSON-RPC error messages and logs detailed diagnostics to stderr only. Internal details stay internal.

## Getting Started — Clone, Deploy, Connect

The setup takes four steps:

**1. Clone the repository:**

```bash
git clone https://github.com/damecek/salesforce-mcp-lib.git
```

**2. Deploy the minimal example to your org:**

```bash
sf project deploy start --source-dir examples/minimal/force-app --target-org <your-org>
```

**3. Connect an AI agent via the proxy:**

```bash
npx salesforce-mcp-lib \
  --instance-url https://your-org.my.salesforce.com \
  --client-id YOUR_CONNECTED_APP_KEY \
  --client-secret YOUR_CONNECTED_APP_SECRET \
  --endpoint /services/apexrest/mcp/minimal
```

**4. Test interactively with the MCP Inspector:**

```bash
npx @modelcontextprotocol/inspector \
  npx salesforce-mcp-lib \
    --instance-url https://your-org.my.salesforce.com \
    --client-id YOUR_KEY \
    --client-secret YOUR_SECRET \
    --endpoint /services/apexrest/mcp/e2e
```

The npm package [`salesforce-mcp-lib`](https://github.com/damecek/salesforce-mcp-lib/blob/main/packages/salesforce-mcp-lib/package.json) (v1.0.3) requires Node.js >= 20 and has zero production dependencies. The Salesforce package is a [2GP unlocked package](https://github.com/damecek/salesforce-mcp-lib/blob/main/sfdx-project.json) with no namespace — you reference classes directly as `McpServer`, not `ns.McpServer`.

The [minimal example](https://github.com/damecek/salesforce-mcp-lib/blob/main/examples/minimal/README.md) is a concept validator — one echo tool, one endpoint. The [E2E example](https://github.com/damecek/salesforce-mcp-lib/blob/main/examples/e2e-http-endpoint/README.md) demonstrates the full range: a SOQL query tool, an org metadata resource, and a dynamic prompt template, all registered in a single endpoint.

## What's Next — And How to Contribute

The project is open source and the framework is production-ready for tools, resources, and prompts. All 11 MCP methods are implemented and verified. The entire stack — 77 Apex classes and 6 TypeScript modules — has zero external production dependencies and is fully auditable in a single repository.

Areas under consideration for future development include framework-level tool authorization, streaming support for long-running operations, and additional examples covering common Salesforce integration patterns.

If you've read this far, the best next step is to try it. Deploy the minimal example to a scratch org, connect it to Claude Desktop or the MCP Inspector, and see what happens when an AI agent can discover your Salesforce capabilities through a standard protocol.

Star the repo, open an issue if something breaks, and tell us what you build with it: [github.com/damecek/salesforce-mcp-lib](https://github.com/damecek/salesforce-mcp-lib)

---

**Hashtags**: #Salesforce #MCP #OpenSource #Apex #AIAgents #EnterpriseAI
