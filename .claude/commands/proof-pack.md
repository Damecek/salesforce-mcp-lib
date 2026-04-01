---
description: Extract verifiable, repo-grounded factual claims for LinkedIn content use
---

## User Input

```text
$ARGUMENTS
```

Consider the user input above (if not empty) as additional focus area or context for claim extraction.

## Purpose

Extract at least 15 verifiable factual claims from the repository, organized into 6 categories. Each claim must cite a specific source file with a verbatim excerpt. The output serves as the factual foundation for all LinkedIn content.

## Instructions

### Step 1: Scan Repository Areas (Priority Order)

Scan the following 7 areas in order. For each area, read key files to extract concrete, quotable facts about the project.

1. **Apex MCP framework classes** (`force-app/main/mcp/classes/`) — Framework capabilities, tool/resource/prompt patterns, server initialization
2. **Apex JSON-RPC core** (`force-app/main/json-rpc/classes/`) — In-repo JSON-RPC 2.0 implementation, zero-dependency protocol, strong typing
3. **TypeScript stdio proxy** (`packages/salesforce-mcp-lib/src/`) — OAuth handling, MCP bridging, stdio transport, zero npm production dependencies
4. **Design documentation** (`docs/`) — Wire-contract audit, authorization feasibility report, protocol compliance evidence
5. **Examples** (`examples/`) — Getting-started simplicity, developer experience, minimal setup
6. **Package configuration** (`sfdx-project.json`, `packages/salesforce-mcp-lib/package.json`) — Version history, namespace, packaging decisions
7. **Specs and plans** (`specs/001-apex-mcp-server/`) — Architectural decisions, design rationale, deliberate choices

### Step 2: Extract Claims

For each content-worthy fact, create a claim entry with these fields:

- **ID**: Unique identifier (e.g., `C-001`, `C-002`, ...)
- **Category**: One of the 6 categories below
- **Statement**: 1–2 sentence factual claim in quotable form
- **Source file**: Repo-relative path to the file this claim is grounded in
- **Excerpt**: Verbatim code snippet or quote from the source file that proves the claim
- **Business value**: 1 sentence translating the technical fact into business value

### Step 3: Organize by Category

Organize all claims into these 6 mandatory categories (every category must have at least 1 claim):

1. **Package Purpose** — What the project does and why it exists
2. **Architecture** — Design decisions, patterns, protocol choices
3. **Developer Experience** — Ease of use, API design, getting started
4. **Security** — Auth model, credential handling, security design
5. **Deployment** — Packaging, distribution, installation
6. **Differentiation** — What makes this different from alternatives (e.g., Agentforce, other MCP implementations)

### Step 4: Exclusion Rules

**NEVER** extract claims from:
- `.env` files or `.env.*` files
- Credential files, external client app configurations
- Any file containing API keys, secrets, passwords, or tokens

If you encounter such a file, silently skip it and log the exclusion in a comment at the bottom of the output file.

### Step 5: Validate

Before writing output, verify:

1. **At least 15 claims** total
2. **All 6 categories represented** — at least 1 claim per category
3. **Every claim has a source file and excerpt** — no unsourced claims
4. **No secret-containing files** were used as sources

### Step 6: Write Output

Write claims to:

```
specs/002-linkedin-content-system/content/claims.md
```

Use this format:

```markdown
# Claims: Salesforce MCP Library

**Generated**: [date]
**Source**: Repository analysis of salesforce-mcp-lib
**Total claims**: [N]

## Package Purpose

### C-001: [Short title]

- **Statement**: [1–2 sentence quotable claim]
- **Source**: `[repo-relative file path]`
- **Excerpt**:
  ```
  [verbatim code/text from source]
  ```
- **Business value**: [1 sentence]

### C-002: [Short title]

...

## Architecture

### C-003: [Short title]

...

## Developer Experience

...

## Security

...

## Deployment

...

## Differentiation

...

---

## Validation

- Total claims: [N] (minimum: 15)
- Categories covered: [6/6]
- All claims sourced: [YES]
- Secret files excluded: [list of skipped files, or "None encountered"]
```

## Error Handling

| Condition | Response |
|---|---|
| Fewer than 15 extractable claims | WARNING in output: "Only [N] claims extracted. Consider expanding repo documentation or relaxing category requirements." Proceed with available claims. |
| Secret-containing file encountered | Silently skip. Log exclusion in comments section at bottom of output. |
| Repository area missing or empty | Skip the area. Note in validation which areas were unavailable. |
