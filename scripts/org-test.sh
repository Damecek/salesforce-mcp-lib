#!/usr/bin/env bash
# Run all Apex tests in the default scratch org
set -euo pipefail

echo "Running Apex tests..."
sf apex run test \
    --test-level RunLocalTests \
    --code-coverage \
    --result-format human \
    --wait 20

echo "Apex tests complete."
