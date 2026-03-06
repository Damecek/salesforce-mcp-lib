#!/usr/bin/env bash
set -euo pipefail

SKIP_FRESH_ORG="${SKIP_FRESH_ORG:-false}"

if [[ "$SKIP_FRESH_ORG" == "true" ]]; then
  ./scripts/task-prepare-skip-org.sh
else
  ./scripts/task-prepare.sh
fi
