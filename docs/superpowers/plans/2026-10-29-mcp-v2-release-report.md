# MCP v2 release report (2026-10-29)

## Released artifacts

- npm `salesforce-mcp-lib@2.0.0`, dist-tag `latest` = 2.0.0.
  - shasum `420760d377ed1e5a4dfa7ee3bff1385d4f4daf4e`
  - integrity `sha512-F8rM8lpGz/mzqeGOgxur8z4loiyXXM6D34tAUeqoCy6QKb8fywCMQdrsipYmcIP6509lrGtHa7uEAocSixK8pQ==`
  - Both match the prepared tarball `/tmp/pk/salesforce-mcp-lib-2.0.0.tgz`.
- Salesforce package `SalesforceMcpLib` 2.0.0.1, `04tdL000000qXzBQAU`, promoted and released, 99% package coverage.
  Install: https://login.salesforce.com/packaging/installPackage.apexp?p0=04tdL000000qXzBQAU
- Git tag `v2.0.0-sf2.0.0-1` (annotated), on the commit that contains this report.

## Post-publication verification

- `npm view salesforce-mcp-lib` returns version 2.0.0, `latest` 2.0.0, and the shasum and integrity above.
- Installed `salesforce-mcp-lib@2.0.0` with `--omit=dev` into an empty temp consumer. `npm ls --omit=dev --all` shows only the package itself, and its `dependencies` is `{}` (zero runtime dependencies).
- `salesforce-mcp-lib --help` prints the usage text. It first prints `Error: missing required configuration: instanceUrl, clientId, endpoint` and exits with code 1, because the parser requires configuration even for `--help`. Starting without arguments gives the same output. Not changed in this release (no source changes).

## Test evidence (earlier runs, not repeated)

188 Apex tests, 97% org-wide and 99% package coverage, 331 npm tests, 144 live tests. No source changed since.

## Documentation updates

Root README, npm README, CLAUDE.md and the handoff now describe npm 2.0.0 as published and give `npx salesforce-mcp-lib@2.0.0` and the Salesforce install URL.

## Limitations kept

- Live OAuth token refresh is not verified.
- Upgrade of a real 1.x org with its old consumer endpoint classes is not verified (only scratch orgs).
- Full MCP compliance is not claimed: no per-tool rate limiting, SSE, tasks, MRTR, subscriptions or logging.
