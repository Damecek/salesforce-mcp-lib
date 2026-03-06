#!/usr/bin/env bash
set -euo pipefail

DEVHUB_ALIAS="${DEVHUB_ALIAS:-mcp-lib-devhub}"
PACKAGE_VERSION_ID="${PACKAGE_VERSION_ID:?Set PACKAGE_VERSION_ID, e.g. 04t...}"

sf package version promote \
  --package "$PACKAGE_VERSION_ID" \
  --target-dev-hub "$DEVHUB_ALIAS" \
  --no-prompt
