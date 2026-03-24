# Validation

## Baseline Sequence

Run validation in this order:

```bash
npm run build
./scripts/harness-url.sh
npm run harness:proxy:smoke
npm run codex:mcp:smoke
```

Why this order:

1. `npm run build` ensures the local bridge CLI exists
2. `./scripts/harness-url.sh` confirms the target endpoint URL
3. `npm run harness:proxy:smoke` validates the bridge against the Salesforce endpoint
4. `npm run codex:mcp:smoke` validates real Codex registration and tool discovery flow

## Secret Gate

Before running `harness:proxy:smoke` or `codex:mcp:smoke`, confirm:

- `SF_CLIENT_ID` is set
- `SF_CLIENT_SECRET` is set

If either is missing, stop and ask for the documented manual export step.
Do not debug unrelated transport behavior first.

## What The Smoke Flow Covers

`harness:proxy:smoke`:

- uses the publishable `salesforce-mcp-lib` `stdio` bridge
- expects client credentials to be configured locally
- validates bridge-to-Salesforce connectivity

`codex:mcp:smoke`:

- temporarily registers a unique Codex MCP server entry
- runs `codex exec`
- asks Codex to call `tools/list`
- removes the temporary registration on exit

## Inspector Debugging

Use Inspector proxy flow when debugging remote HTTP behavior or transport edge cases:

```bash
npm run harness:inspect:smoke
```

This is the preferred debugging path for authenticated remote HTTP validation in this repo.

## Success Criteria

An end-to-end validation is good when:

- the bridge starts without auth errors
- the Apex REST endpoint responds successfully
- `tools/list` succeeds through the bridge
- Codex can see expected tool names through the temporary MCP registration
