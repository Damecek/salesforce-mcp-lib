# salesforce-mcp-lib

Reusable Salesforce Apex MCP library plus a local `stdio` bridge for exposing Salesforce Apex REST MCP endpoints to agent clients over OAuth 2.0 client credentials.

Use it to:
- build/package a generic Apex MCP server runtime for Salesforce
- deploy that runtime to a Salesforce org
- connect local agent clients such as Codex to Salesforce MCP tools exposed by your org

## Install
Install the local bridge directly from npm:

```bash
npx salesforce-mcp-lib \
  --url https://<host>/services/apexrest/mcp \
  --client-id "$SF_CLIENT_ID" \
  --client-secret "$SF_CLIENT_SECRET"
```

Requirements:
- Node.js 20+
- a Salesforce External Client App or Connected App with client credentials flow enabled
- a configured Run As user for that app
- scopes suitable for Apex REST / MCP access

## Example: `execute_soql`
The library itself is a transport/runtime baseline. Actual tool names come from the MCP server you deploy in Salesforce.

If your Salesforce MCP endpoint exposes a tool named `execute_soql`, a minimal local flow looks like this:

```bash
codex mcp add salesforce-org \
  --env "SF_CLIENT_ID=${SF_CLIENT_ID}" \
  --env "SF_CLIENT_SECRET=${SF_CLIENT_SECRET}" \
  -- npx salesforce-mcp-lib --url "https://<host>/services/apexrest/mcp"
```

Then ask the client to call the tool, for example:

```text
Use the salesforce-org MCP server and call execute_soql with:
SELECT Id, Name FROM Account ORDER BY CreatedDate DESC LIMIT 5
```

Direct JSON-RPC shape for the same tool call:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "execute_soql",
    "arguments": {
      "query": "SELECT Id, Name FROM Account ORDER BY CreatedDate DESC LIMIT 5"
    }
  }
}
```

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

These two values are not discoverable from repo state, package metadata, or scratch-org deploy output.
Complete the manual setup in [Manual OAuth App Setup (External Client App)](#manual-oauth-app-setup-external-client-app) and export both values before proxy/Codex smoke runs.

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

## Manual OAuth App Setup (External Client App)
Use this runbook to configure auth in Salesforce and retrieve the two required local secrets.

1. Open Salesforce Setup and navigate to your External Client App.
2. Open the app's **Policies** tab.
3. In **OAuth Flows and External Client App Enhancements**:
   - enable **Client Credentials Flow**
   - set **Run As (Username)** to the integration user that should execute Apex REST / MCP calls
4. In **Plugin Policies** and app OAuth settings, confirm scopes include API access suitable for MCP calls (at minimum `api`).
5. Open the app's **Settings** tab and locate **Consumer Key and Secret**.
6. Reveal/copy the values and export them locally:

```bash
export SF_CLIENT_ID='your-consumer-key'
export SF_CLIENT_SECRET='your-consumer-secret'
```

7. Derive the target MCP endpoint URL and run smoke checks:

```bash
npm run harness:url
npm run harness:proxy:smoke
npm run codex:mcp:smoke
```

Notes:
- `SF_CLIENT_ID` and `SF_CLIENT_SECRET` are manual prerequisites.
- They are not discoverable from repository state, package metadata, or deploy output.
- Connected App is a valid alternative, but this project's canonical setup path is External Client App.

## Examples
Examples live in `examples/` and are intentionally not packaged runtime defaults.

- `examples/minimal`: minimal typed server registration and request dispatch.
- `examples/e2e-http-endpoint`: full endpoint wiring with typed list/call/read/template handlers.
