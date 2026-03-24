# salesforce-mcp-lib

AI-first Salesforce 2GP repository with a reusable Apex MCP library and in-repo JSON-RPC 2.0 core.

## Scope
- Script-first project operations.
- Scratch org deploy/test validation.
- 2GP packaging and release commands.
- Generic MCP library runtime in Apex (no domain business logic).

Out of scope in package runtime:
- Domain-specific tool/resource/template behavior.
- Consumer-specific endpoint wiring.

## Design Principles
- Follow the repository's class-first JSON-RPC and MCP API style.
- Prefer typed DTO classes for MCP arguments, results, and descriptors.
- Keep `Object` and `Map<String, Object>` only at protocol boundaries or for free-form JSON schema fragments.
- Treat examples as typed consumer patterns, not map-plumbing recipes.

## Quick Start
```bash
npm run task:prepare
```

## JSON-RPC Origin
For background, the original JSON-RPC implementation lives at [Damecek/salesforce-apex-json-rpc](https://github.com/Damecek/salesforce-apex-json-rpc).

For simplicity, the latest version used by this package has been moved into [`force-app/main/json-rpc`](/Users/adam/IdeaProjects/salesforce-mcp-lib/force-app/main/json-rpc) and is maintained locally together with the MCP layer.

## Commands
- `npm run org:fresh`
- `npm run org:deploy`
- `npm run org:test`
- `npm run validate`
- `npm run build`
- `npm run test`
- `npm run smoke:cli`
- `npm run codex:mcp:smoke`
- `npm run package:init`
- `npm run release:version`
- `npm run release:promote`
- `npm run release:install`

## npm CLI Package
This repository also contains a publishable workspace package at `packages/salesforce-mcp-lib` for local MCP bridging to Salesforce over OAuth client credentials.

Example:

```bash
npx salesforce-mcp-lib \
  --url https://<host>/services/apexrest/mcp/opportunity/ \
  --client-id "$SF_CLIENT_ID" \
  --client-secret "$SF_CLIENT_SECRET"
```

The bridge exposes the remote Salesforce MCP server over local `stdio` and derives the token endpoint from the same Salesforce origin.

## Codex MCP Smoke
You can validate the publishable bridge through `codex exec` with a temporary MCP server definition:

```bash
SF_CLIENT_ID=... \
SF_CLIENT_SECRET=... \
npm run codex:mcp:smoke
```

Defaults:
- server URL: `https://carvago--devas.sandbox.my.salesforce.com/services/apexrest/mcp/opportunity/`
- expected tool: `opportunity.fetch_with_assets`

The smoke script:
- builds no persistent project config
- temporarily registers a uniquely named MCP server with `codex mcp add`
- runs `codex exec`
- removes the temporary MCP server entry on exit

Optional overrides:
- `SF_MCP_URL`
- `EXPECTED_TOOL_NAME`
- `CODEX_PROMPT`

## Local Proxy Smoke Prerequisites
The local proxy smoke flows are intentionally split between:
- discoverable runtime facts that scripts can derive
- manual local secrets that scripts cannot derive

Discoverable facts:
- target org instance URL from `npm run harness:url`
- default MCP endpoint path `/services/apexrest/mcp`
- supported override path via `MCP_PATH`

Current endpoint shapes used in this repo:
- `/services/apexrest/mcp`
- `/services/apexrest/mcp/opportunity/`

Manual local prerequisite:
- `SF_CLIENT_ID`
- `SF_CLIENT_SECRET`

These two values are not discoverable from repo state or scratch-org deploy state alone. For now, local proxy/Codex smokes require one manual post-setup step in the target org:
1. Open the installed or configured External Client App in Salesforce Setup.
2. Enable the client credentials flow and assign the execution user if that setup is not already complete.
3. Open the app's OAuth settings and retrieve the consumer key and consumer secret.
4. Export them into your shell.

Example:

```bash
export SF_CLIENT_ID='your-consumer-key'
export SF_CLIENT_SECRET='your-consumer-secret'
```

Expected local sequence before proxy-based smoke runs:

```bash
npm run build
npm run harness:url
npm run harness:proxy:smoke
npm run codex:mcp:smoke
```

For a non-default Apex REST endpoint, derive the URL with the supported override:

```bash
MCP_PATH=/services/apexrest/mcp/opportunity/ npm run harness:url
```

If `SF_CLIENT_ID` or `SF_CLIENT_SECRET` is missing, the supported behavior is to stop and complete the manual export step first.

## External Client App
The 2GP source includes a packageable Salesforce External Client App baseline for the CLI/auth integration story.

Packaged metadata covers:
- `ExternalClientApplication`
- `ExtlClntAppOauthSettings`
- `ExtlClntAppGlobalOauthSettings`
- `ExtlClntAppOauthConfigurablePolicies`

Post-install subscriber steps remain required:
- enable the client credentials flow in the installed External Client App OAuth policy
- assign the execution user for the client credentials flow in the installed org
- retrieve or rotate the consumer key and client secret in the installed org
- run the CLI against the installed Apex REST MCP endpoint URL

The packaged header keeps the required `orgScopedExternalApp` value in Salesforce's `[Organization_ID]:[External Client App Name]` shape. That identifier is packaging-org scoped metadata, while generated values such as the consumer key and OAuth link remain out of source control.

Scratch orgs can deploy the Apex package source but Salesforce rejects packaged External Client App global OAuth settings in ephemeral orgs. The repo therefore:
- skips packaged ECA metadata during scratch-org `org:deploy`
- validates the full ECA metadata set against the persistent packaging org via `npm run eca:validate`

## Examples
Examples live in `examples/` and are intentionally not packaged runtime defaults.

- `examples/minimal`: minimal typed server registration and request dispatch.
- `examples/e2e-http-endpoint`: full endpoint wiring with typed list/call/read/template handlers.
