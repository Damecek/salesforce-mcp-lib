#!/usr/bin/env bash
# Push source to the default scratch org
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Pushing source to scratch org..."
sf project deploy start \
    --source-dir "$REPO_ROOT/force-app" \
    --wait 10

echo "Source push complete."
