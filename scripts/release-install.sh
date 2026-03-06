#!/usr/bin/env bash
set -euo pipefail

TARGET_ORG="${TARGET_ORG:-${ORG_ALIAS:-sf-mcp-lib-scratch}}"
PACKAGE_VERSION_ID="${PACKAGE_VERSION_ID:?Set PACKAGE_VERSION_ID, e.g. 04t...}"

sf package install \
  --package "$PACKAGE_VERSION_ID" \
  --target-org "$TARGET_ORG" \
  --wait 30 \
  --publish-wait 10 \
  --security-type AllUsers \
  --no-prompt
