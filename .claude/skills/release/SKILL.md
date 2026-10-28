---
name: release
description: >
  Release new npm + SF 2GP package versions for salesforce-mcp-lib.
  TRIGGER when: user says "release", "publish", "new version", "bump version",
  "npm publish", "package version create", or asks to tag and push a release.
  DO NOT TRIGGER when: writing code (use sf-apex/sf-lwc), deploying metadata
  to an org (use sf-deploy), or running tests only (use sf-testing).
license: MIT
metadata:
  version: "2.0.0"
  author: "Adam Damecek"
---

# release: Dual-Package Release Workflow

Use this skill when the user wants to release new versions of the `salesforce-mcp-lib` project. This project ships **two packages** with independent version numbers:

- **npm**: `salesforce-mcp-lib` — semver in `packages/salesforce-mcp-lib/package.json`
- **SF 2GP**: `SalesforceMcpLib` — `major.minor.patch.NEXT` in `sfdx-project.json`

**Git tag format**: `v{npm-version}-sf{sf-version}` (e.g. `v2.0.0-sf2.0.0-1`)

---

## Pre-flight

0. Ask the user which Dev Hub owns package `0HodL0000002PQXSA2` (alias or username). No Dev Hub is hardcoded anywhere. Check with `sf org list` that it is authenticated. Below, `<hub>` means that answer. Nothing in this flow runs without the user's go.
1. Ask user which packages to release: **both**, **npm only**, or **SF 2GP only**.
2. Ask user the npm semver bump type: **patch**, **minor**, or **major**.
3. For SF 2GP: read `sfdx-project.json` → `versionNumber`. If the current `major.minor.patch` already has a promoted (released) version, it **must be bumped** before creating a new package version — SF will reject the create otherwise. Ask user for the SF version bump in that case.

---

## Step-by-Step Flow

### Step 1: Push pending commits

```bash
git push origin main
```

Ensure the working tree is clean and the release branch is up to date with origin before releasing. For 2.0.0 the work lives on `feat/mcp-v2`: merge it to `main` first (only with the user's go).

### Step 2: Build & test

```bash
cd packages/salesforce-mcp-lib && npm run build && npm test && npm run lint
```

All tests and lint must pass. Do not proceed on failure.

### Step 3: Bump npm version

```bash
cd packages/salesforce-mcp-lib && npm version <patch|minor|major> --no-git-tag-version
```

For 2.0.0 the version is already set in `package.json`, `package-lock.json` and `sfdx-project.json` (`2.0.0.NEXT`): skip the bump and only confirm the numbers. Otherwise this uses `--no-git-tag-version` so we commit the npm bump together with the SF version change in a single release commit.

### Step 4: Bump SF version in sfdx-project.json (if needed)

If the current `versionNumber` is already released, edit it to the new version before creating a package:

```jsonc
// sfdx-project.json
"versionNumber": "X.Y.Z.NEXT"  // bump major.minor.patch as agreed with user
```

### Step 5: Create SF 2GP package version

```bash
./scripts/release-create.sh --target-dev-hub <hub>   # or SF_DEVHUB=<hub> ./scripts/release-create.sh
```

**Critical**: The script fails without `--target-dev-hub` or `SF_DEVHUB`. Never skip validation or coverage.

- Waits up to 30 min. Output JSON contains `SubscriberPackageVersionId` (04t...).
- The CLI auto-adds the new alias to `sfdx-project.json` `packageAliases`.
- Code coverage must pass (>=75%).

### Step 6: Promote SF 2GP package version

```bash
./scripts/release-promote.sh <04t-id> --target-dev-hub <hub>
```

**Critical**: The hub is always explicit. `release-promote.sh` requires `--target-dev-hub` or `SF_DEVHUB` and passes it on, which avoids `NoDefaultDevHubError`.

### Step 6a: Check the install before tagging (first 2.x release)

Verify install and upgrade of a new major version in a scratch org or sandbox that holds the previous version before promoting. After promotion, put the real `04t` id and its install URL (`https://login.salesforce.com/packaging/installPackage.apexp?p0=<04t>`) in the root README. Never publish an install URL for an unpromoted version.

### Step 7: Commit

```bash
git add packages/salesforce-mcp-lib/package.json packages/salesforce-mcp-lib/package-lock.json sfdx-project.json
git commit -m "Release v{npm}-sf{sf}"
```

Single commit with both version changes. Include `package-lock.json` if it changed.

### Step 8: Tag

```bash
git tag v{npm-version}-sf{sf-version}
```

### Step 9: Publish to npm

```bash
cd packages/salesforce-mcp-lib && npm publish
```

- Verify npm session first: `npm whoami`. If not logged in, tell user to run `npm login`.
- If npm requires OTP/browser auth during publish, tell the user to run `npm publish` manually and proceed with the git push.

### Step 10: Push

```bash
git push origin main --tags
```

---

## Verification

After all steps complete:

```bash
npm view salesforce-mcp-lib version                                    # new npm version
sf package version list --packages SalesforceMcpLib --released --json --target-dev-hub <hub>  # new SF version
git tag -l | tail -3                                                   # new tag present
git status                                                             # clean, not ahead of origin
```

---

## Gotchas & Lessons Learned

| Issue | Root Cause | Fix |
|---|---|---|
| `INVALID_INPUT: A released package version with version number X.Y.Z already exists` | SF 2GP rejects new builds under an already-promoted major.minor.patch | Bump the version in `sfdx-project.json` before running `release-create.sh` |
| `NoDefaultDevHubError` on promote or create | No Dev Hub given | Pass `--target-dev-hub <hub>` or set `SF_DEVHUB` (both release scripts require it) |
| `npm error code E404` or `E401` on publish | No active npm session | Run `npm login` or `npm whoami` to verify auth before publishing |
| `npm error code EOTP` | npm requires browser-based OTP | User must complete the browser auth flow or run `npm publish` manually |
