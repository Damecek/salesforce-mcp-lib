# Agent Setup

## Goal

Expose the remote Salesforce Apex REST MCP server to the local agent as a `stdio` MCP process.

The recommended executable is:

```bash
npx salesforce-mcp-lib --url "<full-salesforce-apexrest-mcp-url>"
```

Pass credentials through environment variables unless the client requires inline args:

- `SF_CLIENT_ID`
- `SF_CLIENT_SECRET`
- optional `SF_SCOPE`

## Codex Example

Concrete local registration:

```bash
codex mcp add salesforce-native \
  --env "SF_CLIENT_ID=${SF_CLIENT_ID}" \
  --env "SF_CLIENT_SECRET=${SF_CLIENT_SECRET}" \
  -- npx salesforce-mcp-lib --url "$(./scripts/harness-url.sh)"
```

This mirrors the same pattern used by the repo smoke flow, where Codex launches a local process and speaks MCP over `stdio`.

To remove it later:

```bash
codex mcp remove salesforce-native
```

## Other Agents

For Cursor, Claude Desktop, or any other MCP-capable agent:

- register a local command-based MCP server
- use `npx salesforce-mcp-lib --url "<full-url>"` as the command
- pass `SF_CLIENT_ID` and `SF_CLIENT_SECRET` in the MCP server environment

Do not tell the agent to call Salesforce directly over HTTP unless the client explicitly supports and requires that architecture.

## Operator Notes

- derive the URL first; do not guess it
- if using this repo, prefer `./scripts/harness-url.sh`
- if the user wants a non-default Apex REST path, set `MCP_PATH` before deriving the URL
- if secrets are missing, stop and ask the operator to export them before continuing
