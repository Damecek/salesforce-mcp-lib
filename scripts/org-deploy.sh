#!/usr/bin/env bash
set -euo pipefail

TARGET_ORG="${TARGET_ORG:-${ORG_ALIAS:-sf-mcp-lib-scratch}}"
TARGET_INSTANCE_URL="$(sf org display --target-org "$TARGET_ORG" --json | node -e '
const fs = require("fs");
const payload = JSON.parse(fs.readFileSync(0, "utf8"));
process.stdout.write((payload.result && payload.result.instanceUrl) ? payload.result.instanceUrl : "");
')"

DEPLOY_ARGS=(--target-org "$TARGET_ORG" --wait 20 --json)

if [[ "$TARGET_INSTANCE_URL" == *".scratch.my.salesforce.com"* ]]; then
  while IFS= read -r SOURCE_DIR; do
    DEPLOY_ARGS+=(--source-dir "$SOURCE_DIR")
  done < <(
    find force-app/main/default -mindepth 1 -maxdepth 1 -type d \
      ! -name externalClientApps \
      ! -name extlClntAppGlobalOauthSets \
      ! -name extlClntAppOauthSettings \
      ! -name extlClntAppOauthPolicies \
      | sort
  )
else
  DEPLOY_ARGS+=(--source-dir force-app)
fi

set +e
DEPLOY_OUTPUT="$(sf project deploy start "${DEPLOY_ARGS[@]}" 2>&1)"
DEPLOY_STATUS=$?
set -e

if [[ $DEPLOY_STATUS -eq 0 ]]; then
  echo "$DEPLOY_OUTPUT"
  exit 0
fi

if echo "$DEPLOY_OUTPUT" | grep -Eq '"name"[[:space:]]*:[[:space:]]*"NothingToDeploy"'; then
  echo "No local changes to deploy in force-app (expected for empty template baseline)."
  exit 0
fi

echo "$DEPLOY_OUTPUT" >&2
exit $DEPLOY_STATUS
