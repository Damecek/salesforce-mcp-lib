#!/usr/bin/env bash
# Prepare a feature branch for task work
# Usage: ./task-prepare.sh <branch-name>
set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <branch-name>" >&2
    exit 1
fi

BRANCH="$1"

echo "Creating feature branch: $BRANCH"
git checkout -b "$BRANCH"

echo "Branch $BRANCH ready for development."
