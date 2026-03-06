#!/usr/bin/env bash
set -euo pipefail

DEVHUB_ALIAS="${DEVHUB_ALIAS:-mcp-lib-devhub}"
ORG_ALIAS="${ORG_ALIAS:-sf-mcp-lib-scratch}"
DURATION_DAYS="${DURATION_DAYS:-7}"

sf org create scratch \
  --target-dev-hub "$DEVHUB_ALIAS" \
  --definition-file config/project-scratch-def.json \
  --alias "$ORG_ALIAS" \
  --set-default \
  --duration-days "$DURATION_DAYS" \
  --wait 20
