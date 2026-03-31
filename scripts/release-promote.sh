#!/usr/bin/env bash
# Promote a package version for production use
# Usage: ./release-promote.sh <version-id>
set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <package-version-id>" >&2
    echo "  Example: $0 04t..." >&2
    exit 1
fi

VERSION_ID="$1"

echo "Promoting package version $VERSION_ID..."
sf package version promote \
    --package "$VERSION_ID" \
    --no-prompt

echo "Package version promoted successfully."
