#!/usr/bin/env bash
set -euo pipefail

DEVHUB_ALIAS="${DEVHUB_ALIAS:-mcp-lib-devhub}"

DEVHUB_USERNAME="$(
  sf alias list --json | node -e '
const fs = require("fs");
const payload = JSON.parse(fs.readFileSync(0, "utf8"));
const alias = process.argv[1];
const match = (payload.result || []).find((entry) => entry.alias === alias);
if (!match) {
  process.stderr.write(`Dev Hub alias not found: ${alias}\n`);
  process.exit(1);
}
process.stdout.write(match.value);
' "$DEVHUB_ALIAS"
)"

SCRATCH_ROWS="$(
  sf org list --all --json | node -e '
const fs = require("fs");
const payload = JSON.parse(fs.readFileSync(0, "utf8"));
const devHubUsername = process.argv[1];
const rows = (payload.result.scratchOrgs || [])
  .filter((org) => org.devHubUsername === devHubUsername)
  .map((org) => [org.username, org.status || "", org.alias || ""].join("\t"));
process.stdout.write(rows.join("\n"));
' "$DEVHUB_USERNAME"
)"

if [[ -z "$SCRATCH_ROWS" ]]; then
  echo "No scratch orgs found for Dev Hub ${DEVHUB_ALIAS}."
  exit 0
fi

while IFS=$'\t' read -r SCRATCH_USERNAME SCRATCH_STATUS SCRATCH_ALIAS; do
  [[ -z "$SCRATCH_USERNAME" ]] && continue

  if [[ "$SCRATCH_STATUS" == "Active" ]]; then
    echo "Deleting active scratch org ${SCRATCH_USERNAME}${SCRATCH_ALIAS:+ (${SCRATCH_ALIAS})}..."
    sf org delete scratch --target-org "$SCRATCH_USERNAME" --no-prompt
  else
    echo "Removing local auth for deleted scratch org ${SCRATCH_USERNAME}${SCRATCH_ALIAS:+ (${SCRATCH_ALIAS})}..."
    sf org logout --target-org "$SCRATCH_USERNAME" --no-prompt >/dev/null 2>&1 || true
  fi
done <<< "$SCRATCH_ROWS"
