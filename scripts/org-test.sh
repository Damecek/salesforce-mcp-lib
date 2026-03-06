#!/usr/bin/env bash
set -euo pipefail

TARGET_ORG="${TARGET_ORG:-${ORG_ALIAS:-sf-mcp-lib-scratch}}"

set +e
TEST_OUTPUT="$(sf apex run test \
  --target-org "$TARGET_ORG" \
  --test-level RunLocalTests \
  --result-format human \
  --code-coverage \
  --wait 30 \
  --json 2>&1)"
TEST_STATUS=$?
set -e

if [[ $TEST_STATUS -eq 0 ]]; then
  echo "$TEST_OUTPUT"
  exit 0
fi

if echo "$TEST_OUTPUT" | grep -q "No tests found for category: Apex"; then
  echo "No local Apex tests found in template baseline (expected before implementation)."
  exit 0
fi

echo "$TEST_OUTPUT" >&2
exit $TEST_STATUS
