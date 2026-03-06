#!/usr/bin/env bash
set -euo pipefail

./scripts/org-deploy.sh
./scripts/org-test.sh
