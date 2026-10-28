#!/usr/bin/env bash
# Promote a package version for production use. The Dev Hub must be explicit.
# Usage: ./release-promote.sh <04t-package-version-id> --target-dev-hub <alias-or-username>
#        SF_DEVHUB=<alias-or-username> ./release-promote.sh <04t-package-version-id>
set -euo pipefail

usage() {
    echo "Usage: $0 <04t-package-version-id> --target-dev-hub <alias-or-username>" >&2
    echo "       SF_DEVHUB=<alias-or-username> $0 <04t-package-version-id>" >&2
}

DEVHUB="${SF_DEVHUB:-}"
VERSION_ID=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --target-dev-hub) DEVHUB="${2:-}"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        -*) echo "Unknown option: $1" >&2; usage; exit 1 ;;
        *) VERSION_ID="$1"; shift ;;
    esac
done

if [[ -z "$VERSION_ID" || -z "$DEVHUB" ]]; then
    usage
    exit 1
fi

echo "Promoting package version $VERSION_ID (Dev Hub: ${DEVHUB})..."
sf package version promote \
    --package "$VERSION_ID" \
    --target-dev-hub "$DEVHUB" \
    --no-prompt

echo "Package version promoted successfully."
