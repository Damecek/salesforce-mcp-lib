#!/usr/bin/env bash
set -euo pipefail

TARGET_ORG="${TARGET_ORG:-sf-mcp-lib-scratch}"
PACKAGE_VERSION_ID="${PACKAGE_VERSION_ID:-04tfj000000GCRpAAO}"
REF_DIR="${REF_DIR:-/tmp/apex-json-rpc-ref}"

echo "Installing ApexJsonRpc ${PACKAGE_VERSION_ID} into ${TARGET_ORG}..."
sf package install \
  --package "${PACKAGE_VERSION_ID}" \
  --target-org "${TARGET_ORG}" \
  --wait 30 \
  --publish-wait 10 \
  --security-type AllUsers \
  --no-prompt

echo "Retrieving package source to ${REF_DIR}..."
rm -rf "${REF_DIR}"
mkdir -p "${REF_DIR}"

sf project retrieve start \
  --target-org "${TARGET_ORG}" \
  --package-name "ApexJsonRpc" \
  --target-metadata-dir "${REF_DIR}" \
  --json

echo "Local reference ready in ${REF_DIR}. Do not commit retrieved source."
