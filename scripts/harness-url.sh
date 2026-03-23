#!/usr/bin/env bash
set -euo pipefail

TARGET_ORG="${TARGET_ORG:-${ORG_ALIAS:-sf-mcp-lib-scratch}}"
MCP_PATH="${MCP_PATH:-/services/apexrest/mcp}"
export MCP_PATH

sf org display --target-org "$TARGET_ORG" --json | node -e '
const fs = require("fs");
const payload = JSON.parse(fs.readFileSync(0, "utf8"));
const instanceUrl = payload.result.instanceUrl;
const mcpPath = process.env.MCP_PATH;
if (!instanceUrl) {
  process.stderr.write("Could not resolve instanceUrl for target org.\n");
  process.exit(1);
}
if (!mcpPath || !mcpPath.startsWith("/services/apexrest/")) {
  process.stderr.write("MCP_PATH must start with /services/apexrest/.\n");
  process.exit(1);
}
process.stdout.write(`${instanceUrl}${mcpPath}\n`);
'
