# Install

## Goal

Confirm whether the Salesforce MCP runtime is already installed in the target org before writing Apex code.

## What "installed" means

The target org must already contain the reusable Apex MCP runtime from `salesforce-mcp-lib`, including the packaged External Client App definition.

For this package, the relevant packaged metadata includes:

- Apex MCP runtime classes
- the reusable Apex REST transport
- `ExternalClientApplication`
- `ExtlClntAppOauthSettings`

The packaged External Client App definition is part of the package, but subscriber-specific credentials are still created and managed in the target org.

## Required check

Before implementation, determine which of these is true:

1. the package runtime is already installed in the org
2. the package runtime is missing and must be installed first

Do not assume the runtime exists.

## Install guidance

If the runtime is missing, tell the user that a Salesforce admin or package operator must install the package into Salesforce before continuing.

The install input is a Salesforce package version ID, typically a `04t...` value.

If the user is working from a project that already carries the package version mapping in `sfdx-project.json`, the version ID can be taken from the package aliases there.

Canonical admin install shape:

```bash
sf package install \
  --package 04t... \
  --target-org "<alias>" \
  --wait 30 \
  --publish-wait 10 \
  --security-type AllUsers \
  --no-prompt
```

The skill should describe this as an admin/package-operator Salesforce installation step, not local repository setup.

## Local package requirement

After installation, the agent should retrieve the installed package locally through Salesforce CLI for API reference before implementation proceeds.

Do not describe this as local repository setup, checked-out source, or npm package installation.
