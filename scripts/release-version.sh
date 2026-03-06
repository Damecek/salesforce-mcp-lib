#!/usr/bin/env bash
set -euo pipefail

DEVHUB_ALIAS="${DEVHUB_ALIAS:-mcp-lib-devhub}"
PACKAGE_NAME="${PACKAGE_NAME:-SalesforceMcpLib}"
VERSION_NAME="${VERSION_NAME:-v0.1.0}"
VERSION_DESC="${VERSION_DESC:-Generic Salesforce MCP library baseline}"

./scripts/validate.sh

sf package version create \
  --package "$PACKAGE_NAME" \
  --version-name "$VERSION_NAME" \
  --version-description "$VERSION_DESC" \
  --code-coverage \
  --installation-key-bypass \
  --target-dev-hub "$DEVHUB_ALIAS" \
  --wait 90
