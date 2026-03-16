#!/usr/bin/env bash
set -euo pipefail

TARGET_ORG="${TARGET_ORG:-${ORG_ALIAS:-sf-mcp-lib-scratch}}"

sf project deploy start \
  --target-org "$TARGET_ORG" \
  --source-dir dev/mcp-harness/force-app \
  --wait 20
