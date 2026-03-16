#!/usr/bin/env bash
set -euo pipefail

TARGET_ORG="${TARGET_ORG:-${ORG_ALIAS:-sf-mcp-lib-scratch}}"

set +e
ORG_DISPLAY_JSON="$(sf org display --target-org "$TARGET_ORG" --json 2>&1)"
ORG_DISPLAY_STATUS=$?
set -e

if [[ $ORG_DISPLAY_STATUS -ne 0 ]]; then
  if echo "$ORG_DISPLAY_JSON" | grep -qiE 'No authorization information found|not found|No org configuration found'; then
    echo "Scratch org ${TARGET_ORG} is not authorized locally. Nothing to delete."
    exit 0
  fi

  echo "$ORG_DISPLAY_JSON" >&2
  exit $ORG_DISPLAY_STATUS
fi

ORG_USERNAME="$(printf '%s' "$ORG_DISPLAY_JSON" | node -e '
const fs = require("fs");
const payload = JSON.parse(fs.readFileSync(0, "utf8"));
const result = payload.result || {};
if (!result.username) process.exit(1);
process.stdout.write(result.username);
')"

ORG_IS_SCRATCH="$(printf '%s' "$ORG_DISPLAY_JSON" | node -e '
const fs = require("fs");
const payload = JSON.parse(fs.readFileSync(0, "utf8"));
const result = payload.result || {};
process.stdout.write(String(Boolean(result.isScratch)));
')"

if [[ "$ORG_IS_SCRATCH" != "true" ]]; then
  echo "Target org ${ORG_USERNAME} is not a scratch org. Skipping delete."
  exit 0
fi

SCRATCH_STATUS="$(
  sf org list --all --json | node -e '
const fs = require("fs");
const payload = JSON.parse(fs.readFileSync(0, "utf8"));
const username = process.argv[1];
const match = (payload.result.scratchOrgs || []).find((org) => org.username === username);
if (!match) process.exit(0);
process.stdout.write(match.status || "");
' "$ORG_USERNAME"
)"

if [[ -z "$SCRATCH_STATUS" || "$SCRATCH_STATUS" == "Deleted" ]]; then
  echo "Scratch org ${ORG_USERNAME} is already deleted. Logging out local auth."
  sf org logout --target-org "$ORG_USERNAME" --no-prompt >/dev/null 2>&1 || true
  exit 0
fi

echo "Deleting scratch org ${ORG_USERNAME}..."
sf org delete scratch --target-org "$ORG_USERNAME" --no-prompt
