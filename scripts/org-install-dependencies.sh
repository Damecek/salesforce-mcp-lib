#!/usr/bin/env bash
set -euo pipefail

TARGET_ORG="${TARGET_ORG:-${ORG_ALIAS:-sf-mcp-lib-scratch}}"

DEPENDENCY_IDS="$(
  node -e '
const fs = require("fs");
const project = JSON.parse(fs.readFileSync("sfdx-project.json", "utf8"));
const packageDirectories = Array.isArray(project.packageDirectories) ? project.packageDirectories : [];
const ids = [];

for (const directory of packageDirectories) {
  const dependencies = Array.isArray(directory.dependencies) ? directory.dependencies : [];
  for (const dependency of dependencies) {
    const value = dependency && typeof dependency.package === "string" ? dependency.package.trim() : "";
    if (/^04t[A-Za-z0-9]{12,15}$/.test(value) && !ids.includes(value)) {
      ids.push(value);
    }
  }
}

process.stdout.write(ids.join("\n"));
'
)"

if [[ -z "$DEPENDENCY_IDS" ]]; then
  echo "No package version dependencies declared in sfdx-project.json."
  exit 0
fi

INSTALLED_JSON="$(sf package installed list --target-org "$TARGET_ORG" --json)"

while IFS= read -r PACKAGE_VERSION_ID; do
  [[ -z "$PACKAGE_VERSION_ID" ]] && continue

  IS_INSTALLED="$(
    printf '%s' "$INSTALLED_JSON" | node -e '
const fs = require("fs");
const payload = JSON.parse(fs.readFileSync(0, "utf8"));
const packageVersionId = process.argv[1];
const installed = Array.isArray(payload.result) ? payload.result : [];
process.stdout.write(installed.some((entry) => entry.SubscriberPackageVersionId === packageVersionId) ? "true" : "false");
' "$PACKAGE_VERSION_ID"
  )"

  if [[ "$IS_INSTALLED" == "true" ]]; then
    echo "Package dependency ${PACKAGE_VERSION_ID} is already installed in ${TARGET_ORG}."
    continue
  fi

  echo "Installing package dependency ${PACKAGE_VERSION_ID} into ${TARGET_ORG}..."
  PACKAGE_VERSION_ID="$PACKAGE_VERSION_ID" ./scripts/release-install.sh
done <<< "$DEPENDENCY_IDS"
