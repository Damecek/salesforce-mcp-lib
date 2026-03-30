#!/usr/bin/env bash
# Full validation suite: Apex tests + TypeScript compilation + lint
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

EXIT_CODE=0

echo "=== Validation Suite ==="
echo ""

# TypeScript compilation check
echo "--- TypeScript Build ---"
if [ -d "${PROJECT_ROOT}/packages/salesforce-mcp-lib" ]; then
  cd "${PROJECT_ROOT}/packages/salesforce-mcp-lib"
  if npm run build 2>&1; then
    echo "TypeScript build: PASS"
  else
    echo "TypeScript build: FAIL"
    EXIT_CODE=1
  fi
  cd "${PROJECT_ROOT}"
else
  echo "TypeScript package not found, skipping."
fi

echo ""

# TypeScript tests
echo "--- TypeScript Tests ---"
if [ -d "${PROJECT_ROOT}/packages/salesforce-mcp-lib" ]; then
  cd "${PROJECT_ROOT}/packages/salesforce-mcp-lib"
  if npm test 2>&1; then
    echo "TypeScript tests: PASS"
  else
    echo "TypeScript tests: FAIL"
    EXIT_CODE=1
  fi
  cd "${PROJECT_ROOT}"
else
  echo "TypeScript package not found, skipping."
fi

echo ""

# Apex tests (requires connected scratch org)
echo "--- Apex Tests ---"
if sf org display 2>/dev/null; then
  if sf apex run test --test-level RunLocalTests --code-coverage --result-format human --wait 10 2>&1; then
    echo "Apex tests: PASS"
  else
    echo "Apex tests: FAIL"
    EXIT_CODE=1
  fi
else
  echo "No default scratch org configured, skipping Apex tests."
fi

echo ""
echo "=== Validation Complete (exit code: ${EXIT_CODE}) ==="
exit ${EXIT_CODE}
