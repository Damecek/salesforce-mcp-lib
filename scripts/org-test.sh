#!/usr/bin/env bash
# Run all Apex tests in the default scratch org
set -euo pipefail

echo "Running Apex tests..."
sf apex run test \
    --synchronous \
    --code-coverage \
    --result-format human \
    --wait 10

echo "Apex tests complete."
