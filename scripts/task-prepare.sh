#!/usr/bin/env bash
set -euo pipefail

./scripts/org-fresh.sh
./scripts/org-install-dependencies.sh
./scripts/org-deploy.sh
./scripts/org-test.sh
