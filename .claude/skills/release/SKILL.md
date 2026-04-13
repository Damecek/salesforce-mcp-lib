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
  version: "1.0.0"
  author: "Adam Damecek"
---

# release: Dual-Package Release Workflow

Use this skill when the user wants to release new versions of the `salesforce-mcp-lib` project. This project ships **two packages** with independent version numbers:

- **npm**: `salesforce-mcp-lib` — semver in `packages/salesforce-mcp-lib/package.json`
- **SF 2GP**: `SalesforceMcpLib` — `major.minor.patch.NEXT` in `sfdx-project.json`

**Git tag format**: `v{npm-version}-sf{sf-version}` (e.g. `v1.1.0-sf1.2.0-1`)

---

## Pre-flight

1. Ask user which packages to release: **both**, **npm only**, or **SF 2GP only**.
2. Ask user the npm semver bump type: **patch**, **minor**, or **major**.
3. For SF 2GP: read `sfdx-project.json` → `versionNumber`. If the current `major.minor.patch` already has a promoted (released) version, it **must be bumped** before creating a new package version — SF will reject the create otherwise. Ask user for the SF version bump in that case.

---

## Step-by-Step Flow

### Step 1: Push pending commits

```bash
git push origin main
```

Ensure the working tree is clean and `main` is up to date with origin before releasing.

### Step 2: Build & test

```bash
cd packages/salesforce-mcp-lib && npm run build && npm test && npm run lint
```

All tests and lint must pass. Do not proceed on failure.

### Step 3: Bump npm version

```bash
cd packages/salesforce-mcp-lib && npm version <patch|minor|major> --no-git-tag-version
```

Uses `--no-git-tag-version` so we commit the npm bump together with the SF version change in a single release commit.

### Step 4: Bump SF version in sfdx-project.json (if needed)

If the current `versionNumber` is already released, edit it to the new version before creating a package:

```jsonc
// sfdx-project.json
"versionNumber": "X.Y.Z.NEXT"  // bump major.minor.patch as agreed with user
```

### Step 5: Create SF 2GP package version

```bash
./scripts/release-create.sh --target-org mcp-lib-devhub
```

**Critical**: Always pass `--target-org mcp-lib-devhub` — no default devhub is configured.

- Waits up to 30 min. Output JSON contains `SubscriberPackageVersionId` (04t...).
- The CLI auto-adds the new alias to `sfdx-project.json` `packageAliases`.
- Code coverage must pass (>=75%).

### Step 6: Promote SF 2GP package version

```bash
sf package version promote --package <04t-id> --no-prompt --target-dev-hub mcp-lib-devhub
```

**Critical**: Always pass `--target-dev-hub mcp-lib-devhub` explicitly. Do NOT use `scripts/release-promote.sh` alone — it does not pass the devhub flag and will fail with `NoDefaultDevHubError`.

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
sf package version list --packages SalesforceMcpLib --released --json  # new SF version
git tag -l | tail -3                                                   # new tag present
git status                                                             # clean, not ahead of origin
```

---

## Gotchas & Lessons Learned

| Issue | Root Cause | Fix |
|---|---|---|
| `INVALID_INPUT: A released package version with version number X.Y.Z already exists` | SF 2GP rejects new builds under an already-promoted major.minor.patch | Bump the version in `sfdx-project.json` before running `release-create.sh` |
| `NoDefaultDevHubError` on promote | `scripts/release-promote.sh` doesn't pass `--target-dev-hub` | Run `sf package version promote` directly with `--target-dev-hub mcp-lib-devhub` |
| `npm error code E404` or `E401` on publish | No active npm session | Run `npm login` or `npm whoami` to verify auth before publishing |
| `npm error code EOTP` | npm requires browser-based OTP | User must complete the browser auth flow or run `npm publish` manually |
