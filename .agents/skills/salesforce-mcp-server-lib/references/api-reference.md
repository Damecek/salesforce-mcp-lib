# API Reference

## Goal

Retrieve the installed Salesforce package locally for API reference and examples before generating Apex code.

## Required behavior

Do not tell the agent to install an npm package for API reference. The relevant runtime is the Salesforce package installed in the target org.

The agent should retrieve the installed Salesforce package locally with `sf` so it can inspect the real Apex metadata and examples before generating code.

Preferred order:

1. retrieve the installed package or relevant metadata from the target org with Salesforce CLI
2. inspect the retrieved Apex runtime and transport classes locally
3. inspect local examples that demonstrate server registration and HTTP wiring
4. only then generate implementation guidance or code

Do not rely on memory when the package can be inspected locally.

## Retrieval guidance

Use Salesforce CLI retrieval against the target org, for example:

```bash
sf project retrieve start --package-name "SalesforceMcpLib" --target-org "<alias>"
```

If package-name retrieval is not suitable for the environment, retrieve the installed metadata with an explicit manifest or metadata selection and inspect the resulting local files.

The agent should mention the exact retrieval command it used.

## Canonical local sources after retrieve

After retrieval, start with:

- the retrieved `McpServer` classes
- the retrieved `McpHttpTransport` class
- local example Apex files that demonstrate server registration and HTTP wiring

## What to extract

Before implementation, pull out the exact local patterns for:

- `McpServer` construction
- typed tool/resource/template registration
- `McpHttpTransport.handlePost(...)`
- endpoint URL shape
- `npx salesforce-mcp-lib --url ...` bridge usage

The output should mention the exact files or docs actually inspected.
