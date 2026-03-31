#!/usr/bin/env bash
# Create a new package version with code coverage
# Usage: ./release-create.sh [--target-org <alias>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET_ORG=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --target-org) TARGET_ORG="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

ORG_FLAG=""
if [[ -n "$TARGET_ORG" ]]; then
    ORG_FLAG="--target-dev-hub $TARGET_ORG"
fi

echo "Creating package version with code coverage..."
sf package version create \
    --package SalesforceMcpLib \
    --installation-key-bypass \
    --code-coverage \
    --wait 30 \
    $ORG_FLAG \
    --json

echo "Package version created successfully."
