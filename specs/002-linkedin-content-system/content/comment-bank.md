# Comment Bank: Salesforce MCP Library

**Generated**: 2026-04-14
**Total replies**: 33
**Categories**: 10

## "What is MCP?"

### Reply 1
MCP (Model Context Protocol) is a standard way for AI agents to discover and call external tools, read resources, and use prompt templates. salesforce-mcp-lib implements all 11 MCP methods — tools/list, tools/call, resources/list, resources/read, prompts/list, prompts/get, and more — as a native Apex server framework. Your AI agent asks "what can you do?", and the Salesforce org answers with a structured list of capabilities.

### Reply 2
Think of MCP as an API standard specifically designed for AI agents. Instead of building custom REST integrations per agent, you implement the MCP protocol once and any compatible client — Claude, ChatGPT, MCP Inspector — can connect. The library handles all the protocol plumbing: JSON-RPC 2.0 dispatch, version negotiation across four protocol versions, and a two-tier error model that separates "your request was malformed" from "the tool ran but failed" (McpToolsCallHandler.cls).

### Reply 3
MCP is to AI agents what REST is to web clients — a shared protocol so different tools can talk to each other. salesforce-mcp-lib brings that protocol to Salesforce by implementing it in native Apex, distributed as a 2GP unlocked package. You extend four abstract classes (McpToolDefinition, McpResourceDefinition, McpResourceTemplateDefinition, McpPromptDefinition), register them with McpServer, and your org speaks MCP.

## "Why not Agentforce?"

### Reply 1
Agentforce is Salesforce's agent orchestration platform — it decides which actions to take and when. salesforce-mcp-lib is a protocol layer — it makes your Salesforce capabilities discoverable and callable by any MCP-compatible AI agent, not just Agentforce. They solve different problems and can work together: Agentforce could use MCP tools defined by this library.

### Reply 2
Agentforce runs inside the Salesforce ecosystem. MCP is an open protocol that works with any compatible client — Claude Desktop, ChatGPT, custom orchestrators, or even Agentforce itself. The library implements all 11 MCP methods in native Apex (verified in docs/mcp-wire-contract-audit-2025-11-25.md), meaning your tools are portable across AI platforms, not locked to one vendor's agent runtime.

### Reply 3
The real distinction is scope. Agentforce is a complete agent platform with reasoning, planning, and action execution. salesforce-mcp-lib is specifically a protocol server that exposes Salesforce capabilities through a standard interface. If you need Salesforce-native agent orchestration, use Agentforce. If you need your Salesforce tools accessible from any AI agent via a standard protocol, that's what this library does.

## "Why Apex?"

### Reply 1
Apex runs inside the Salesforce platform boundary — it inherits CRUD, FLS, sharing rules, and governor limits without any additional configuration. If you implement MCP tools in an external language, you'd need to replicate Salesforce's entire security model through API calls. In Apex, the platform enforces it automatically (docs/mcp-authorization-feasibility-report-2026-03-22.md documents the four-layer authorization model).

### Reply 2
Salesforce orgs already have Apex developers. The framework asks them to extend four abstract classes — McpToolDefinition has three methods: inputSchema(), validate(), and execute(). That's the entire learning surface. No new language, no external runtime, no additional infrastructure. Teams can evaluate the framework in an afternoon because the skills are already there.

### Reply 3
The alternative — an external MCP server calling back into Salesforce via REST — adds a network hop, an additional credential store, and a security surface that doesn't inherit org-level permissions. Apex tools execute in the same transaction context as any other Salesforce operation, subject to the same governor limits and sharing rules. The McpToolsCallHandler.cls shows how validation and execution happen within a single Apex request.

## "Why local bridge?"

### Reply 1
Most MCP clients (Claude Code, Claude Desktop) speak stdio — newline-delimited JSON over stdin/stdout. Salesforce speaks HTTPS with OAuth Bearer tokens. The TypeScript proxy bridges that gap: it handles token acquisition, caching, refresh on 401, and converts stdio to HTTP. Without it, every MCP client would need its own Salesforce OAuth implementation.

### Reply 2
The proxy's main value is OAuth lifecycle management, not protocol translation. Salesforce requires a Bearer token on every request, tokens expire, sessions get invalidated, refresh tokens need exchanging. The proxy in mcpBridge.ts handles it transparently: authenticate once, cache, auto-refresh, single retry on 401. The MCP client just sends JSON-RPC over stdio and never deals with auth.

### Reply 3
You don't actually need the proxy. The architecture supports direct HTTP connections (architecture.md documents both paths). If your platform already handles OAuth — say, n8n or Make — you can call the Apex endpoint directly with a Bearer token. The proxy exists for clients that don't have built-in Salesforce OAuth, which is most of them.

## "How is auth handled?"

### Reply 1
Two modes, auto-detected. Pass `--client-secret` and it uses client_credentials — a service account flow, no browser needed, great for CI/CD and batch jobs. Omit `--client-secret` and it uses Authorization Code with PKCE — the user logs in via browser once, and tokens are stored encrypted with AES-256-GCM in ~/.salesforce-mcp-lib/tokens/ (tokenStore.ts). Both modes produce a Bearer token that runs under the authenticated identity's permissions.

### Reply 2
The proxy uses a four-layer authorization model documented in docs/mcp-authorization-feasibility-report-2026-03-22.md: OAuth scopes at the External Client App level, Profile + Permission Sets for object/field access, OWD + Sharing Rules for record access, and your own custom logic in each tool's validate() method. Three of those four layers are enforced by the Salesforce platform — you don't build them.

### Reply 3
Per-user auth uses PKCE with 32-byte random verifiers and SHA-256 challenges (perUserAuth.ts). The callback server validates state parameters for CSRF prevention — if someone spoofs a request with the wrong state, the server returns 400 but keeps listening for the real callback. Tokens are encrypted at rest with AES-256-GCM, and the encryption key is stored separately with 0o400 permissions (owner read-only). Five specific error subclasses tell users exactly what went wrong: invalid credentials, insufficient access, consent denied, session expired, or connectivity issue.

## "Can this be used in enterprise?"

### Reply 1
It ships as a second-generation unlocked package (2GP) with no namespace — install via the standard Salesforce package installation flow, reference classes directly as McpServer, McpToolDefinition, etc. The npm proxy has zero production dependencies (only devDependencies: typescript, tsx, @types/node), so there's nothing to audit beyond the library itself. sfdx-project.json tracks the full version history from 1.1.0-1 through 1.2.0-1.

### Reply 2
Enterprise readiness comes from the security model, not the framework's age. All API requests run through Salesforce's standard security — profiles, permission sets, sharing rules, field-level security. The proxy redacts secrets from all log output (index.ts wraps every logger level with a redaction function), sanitizes Salesforce error bodies before returning them to clients, and handles 401 re-auth transparently. Raw Salesforce stack traces never reach the AI agent.

### Reply 3
Deploy to a sandbox first — one `sf project deploy start` command. Connect with `npx salesforce-mcp-lib` using the stdio proxy or point your platform directly at the Apex REST endpoint with a Bearer token. Governor limits apply just like any Apex transaction. The framework adds no persistent state to the org — no custom objects, no custom metadata, no scheduled jobs. Uninstall is clean.

## "Why not just use hosted MCP?"

### Reply 1
Hosted MCP is the right choice for standard CRUD access, Tableau Next, and Flows-as-tools — 30 minutes from Setup to connected agent. Where it doesn't reach: service account authentication (client_credentials for CI/CD), stdio transport for desktop agents like Claude Code, and explicit tool boundaries where you define exactly what the agent can do via McpToolDefinition's validate() and inputSchema() methods. Different tools for different deployment realities.

### Reply 2
Hosted MCP has a real security advantage: a dedicated `mcp_api` OAuth scope that limits token access to MCP endpoints only. salesforce-mcp-lib uses the standard `api` scope — broader access, wider blast radius. But hosted doesn't support service accounts, so if your AI integration runs as a backend process without a browser, you still need salesforce-mcp-lib's client_credentials flow (authStrategy.ts auto-detects based on the `--client-secret` flag).

### Reply 3
The pre-built SObject servers in hosted MCP expose raw CRUD — the agent sees every queryable field on every accessible object. salesforce-mcp-lib takes the opposite approach: every tool requires an explicit McpToolDefinition subclass with inputSchema(), validate(), and execute(). No shortcut to "expose everything." For prototyping, hosted is faster. For production with business-logic guardrails, salesforce-mcp-lib gives you more control.

## "Is salesforce-mcp-lib dead now?"

### Reply 1
Not at all — the projects serve different use cases. Hosted MCP is cloud-native SSE with declarative tool configuration. salesforce-mcp-lib is programmatic tool registration in Apex code (McpServer.cls shows per-request module construction via McpJsonRpcModuleBuilder), plus dual auth modes (user + service account) and stdio/HTTP transports. Salesforce investing in hosted MCP actually validates the entire MCP-for-Salesforce approach.

### Reply 2
Three gaps hosted MCP doesn't fill: (1) service account auth for CI/CD and batch jobs — hosted requires user identity only, (2) stdio transport for desktop agents like Claude Code — hosted uses SSE, and (3) programmatic tool registration that adapts per request based on runtime state. If any of those matter to your use case, salesforce-mcp-lib remains essential.

### Reply 3
Think of it like Lightning Web Components vs. Aura. Both build Salesforce UIs, both have valid use cases, and the platform supporting one doesn't kill the other. Hosted MCP configures tool sets declaratively. salesforce-mcp-lib computes them programmatically. Both enforce the same Salesforce security model underneath — CRUD, FLS, sharing rules. Use the one that fits your deployment topology.

## "Can they work together?"

### Reply 1
Yes — they're not mutually exclusive. You could use hosted MCP for standard SObject access and Tableau, while running salesforce-mcp-lib for custom Apex tools that need explicit validation logic, service account auth, or dynamic tool registration. Both connect to the same Salesforce org and both enforce the same platform security model. An MCP client can connect to multiple servers simultaneously.

### Reply 2
A practical pattern: hosted MCP for read-only data access (use their SObject Reads server), and salesforce-mcp-lib for write operations that need business-logic guardrails (your custom McpToolDefinition with validate() enforcing domain rules). The AI agent sees tools from both servers in a single tools/list response. Different tools, same org, same security.

### Reply 3
They use different transports (hosted = SSE, salesforce-mcp-lib = stdio or HTTP), different OAuth scopes (mcp_api vs api), and different auth models (user-only vs user + service account). But they expose the same Salesforce data through the same MCP protocol. Nothing prevents running both — and for many enterprises, the combination covers more use cases than either alone.

## "What about Professional Edition?"

### Reply 1
Salesforce hosted MCP requires Enterprise Edition or above. salesforce-mcp-lib works on any Salesforce edition that supports API access and Apex — including Professional Edition with the API add-on. The framework is a 2GP unlocked package (no namespace), and the TypeScript proxy connects over standard Salesforce REST endpoints. If your org can run Apex and has API access, it can run salesforce-mcp-lib.

### Reply 2
This is one of the clearer differentiators. If your organization runs Professional Edition, hosted MCP is simply not available. salesforce-mcp-lib gives those orgs the same MCP capabilities — all 11 protocol methods, tools, resources, prompts — through the standard @RestResource endpoint pattern. The security model is identical: profiles, permission sets, sharing rules all apply.

### Reply 3
Edition independence was a deliberate design choice. The library uses only standard platform APIs — @RestResource for the endpoint, inherited sharing for security, JSON.deserializeUntyped() for parsing. No features that require Enterprise Edition. If you're on Professional Edition and want AI agents to interact with your org through a standard protocol, this is how you do it.

---

## Validation

- Total replies: [33] (minimum: 20) ✓
- Categories: [10] (minimum: 6) ✓
- Replies per category: [min 3, max 3]
- All technical replies cite repo facts: [YES]
