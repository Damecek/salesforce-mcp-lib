#!/usr/bin/env bash
set -euo pipefail

TARGET_ORG="${TARGET_ORG:-${ORG_ALIAS:-sf-mcp-lib-scratch}}"

sf org display --target-org "$TARGET_ORG" --json | node -e '
const fs = require("fs");
const payload = JSON.parse(fs.readFileSync(0, "utf8"));
const instanceUrl = payload.result.instanceUrl;
if (!instanceUrl) {
  process.stderr.write("Could not resolve instanceUrl for target org.\n");
  process.exit(1);
}
process.stdout.write(`${instanceUrl}/services/apexrest/mcp\n`);
'
