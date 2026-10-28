#!/usr/bin/env bash
# Create a new package version with code coverage (validation is never skipped).
# The Dev Hub must be explicit: no default Dev Hub is assumed.
# Usage: ./release-create.sh --target-dev-hub <alias-or-username>
#        SF_DEVHUB=<alias-or-username> ./release-create.sh
# --target-org is accepted as a deprecated alias of --target-dev-hub.
set -euo pipefail

usage() {
    echo "Usage: $0 --target-dev-hub <alias-or-username>" >&2
    echo "       SF_DEVHUB=<alias-or-username> $0" >&2
    echo "The Dev Hub must own package SalesforceMcpLib (0Ho... in sfdx-project.json)." >&2
}

DEVHUB="${SF_DEVHUB:-}"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --target-dev-hub) DEVHUB="${2:-}"; shift 2 ;;
        --target-org)
            echo "Warning: --target-org is deprecated, use --target-dev-hub." >&2
            DEVHUB="${2:-}"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

if [[ -z "$DEVHUB" ]]; then
    echo "Error: no Dev Hub given." >&2
    usage
    exit 1
fi

echo "Creating package version with code coverage (Dev Hub: ${DEVHUB})..."
sf package version create \
    --package SalesforceMcpLib \
    --installation-key-bypass \
    --code-coverage \
    --wait 30 \
    --target-dev-hub "$DEVHUB" \
    --json

echo "Package version created. It is NOT released until you promote it (scripts/release-promote.sh)."
