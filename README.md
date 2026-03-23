# salesforce-mcp-lib

AI-first Salesforce 2GP repository with a reusable Apex MCP library built on top of ApexJsonRpc.

## Scope
- Script-first project operations.
- Scratch org deploy/test validation.
- 2GP packaging and release commands.
- Generic MCP library runtime in Apex (no domain business logic).

Out of scope in package runtime:
- Domain-specific tool/resource/template behavior.
- Consumer-specific endpoint wiring.

## Design Principles
- Follow ApexJsonRpc's current class-first API style.
- Prefer typed DTO classes for MCP arguments, results, and descriptors.
- Keep `Object` and `Map<String, Object>` only at protocol boundaries or for free-form JSON schema fragments.
- Treat examples as typed consumer patterns, not map-plumbing recipes.

## Quick Start
```bash
npm run task:prepare
```

## ApexJsonRpc Local Reference Workflow
Pin and inspect ApexJsonRpc locally before changing the library API surface.

```bash
npm run ref:apexjsonrpc
```

Defaults:
- `TARGET_ORG=sf-mcp-lib-scratch`
- `PACKAGE_VERSION_ID=04tfj000000GCRpAAO`
- `REF_DIR=/tmp/apex-json-rpc-ref`

The script installs the package and retrieves source into `/tmp/...` for local reference only. Never commit retrieved package source.

## Commands
- `npm run org:fresh`
- `npm run org:deploy`
- `npm run org:test`
- `npm run validate`
- `npm run build`
- `npm run test`
- `npm run smoke:cli`
- `npm run codex:mcp:smoke`
- `npm run ref:apexjsonrpc`
- `npm run package:init`
- `npm run release:version`
- `npm run release:promote`
- `npm run release:install`

## npm CLI Package
This repository also contains a publishable workspace package at `packages/salesforce-mcp-lib` for local MCP bridging to Salesforce over OAuth client credentials.

Example:

```bash
npx salesforce-mcp-lib \
  --url https://<host>/services/apexrest/opportunity/mcp \
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
