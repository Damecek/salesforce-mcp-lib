#!/usr/bin/env bash
set -euo pipefail

DEVHUB_ALIAS="${DEVHUB_ALIAS:-mcp-lib-devhub}"
MANIFEST_PATH="manifest/external-client-app.xml"
RETRIEVE_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$RETRIEVE_DIR"
}

trap cleanup EXIT

sf project deploy start \
  --manifest "$MANIFEST_PATH" \
  --target-org "$DEVHUB_ALIAS" \
  --wait 20

sf project retrieve start \
  --manifest "$MANIFEST_PATH" \
  --target-org "$DEVHUB_ALIAS" \
  --target-metadata-dir "$RETRIEVE_DIR"
