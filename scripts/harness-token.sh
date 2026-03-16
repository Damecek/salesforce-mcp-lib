#!/usr/bin/env bash
set -euo pipefail

TARGET_ORG="${TARGET_ORG:-${ORG_ALIAS:-sf-mcp-lib-scratch}}"

sf org display --target-org "$TARGET_ORG" --json | node -e '
const fs = require("fs");
const payload = JSON.parse(fs.readFileSync(0, "utf8"));
const accessToken = payload.result.accessToken;
if (!accessToken) {
  process.stderr.write("Could not resolve accessToken for target org.\n");
  process.exit(1);
}
process.stdout.write(`${accessToken}\n`);
'
