#!/usr/bin/env bash
set -euo pipefail

TARGET_ORG="${TARGET_ORG:-${ORG_ALIAS:-sf-mcp-lib-scratch}}"
DEPLOY_ARGS=(--target-org "$TARGET_ORG" --wait 20 --json --source-dir force-app)

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
