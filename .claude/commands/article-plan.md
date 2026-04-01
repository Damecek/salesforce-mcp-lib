---
description: Generate a detailed outline for a long-form technical article about the Salesforce MCP library
---

## User Input

```text
$ARGUMENTS
```

Consider the user input above (if not empty) as additional context, angle, or target audience for the article.

## Purpose

Generate a detailed section-by-section outline for a single long-form article (1500–2500 words) about the Salesforce MCP library. The outline maps every section to verifiable repo claims and specific file references, ensuring the final article is grounded in facts and links back to the project.

## Prerequisite Check

**Before doing anything else**, verify this required file exists:

1. Read `specs/002-linkedin-content-system/content/claims.md`

**If `claims.md` is missing**, output the following and STOP — do not proceed:

```
ERROR: Missing prerequisite.
- Claims not found at specs/002-linkedin-content-system/content/claims.md
- Run `/proof-pack` first to generate it.
```

## Instructions

### Step 1: Scan Repository Areas

Scan the following 7 repository areas to gather fresh context beyond what claims.md already captures. Read key files from each area — sample enough to understand capabilities, architecture, and value proposition.

1. **Apex MCP framework classes** (`force-app/main/mcp/classes/`) — Framework capabilities, design patterns, developer experience
2. **Apex JSON-RPC core** (`force-app/main/json-rpc/classes/`) — Zero-dependency protocol implementation, strong typing
3. **TypeScript stdio proxy** (`packages/salesforce-mcp-lib/src/`) — OAuth, MCP bridging, stdio transport, zero npm dependencies
4. **Design documentation** (`docs/`) — Wire-contract audit, authorization feasibility report, protocol compliance
5. **Examples** (`examples/`) — Getting-started simplicity, developer experience
6. **Package configuration** (`sfdx-project.json`, `packages/salesforce-mcp-lib/package.json`) — Version history, packaging, distribution
7. **Specs and plans** (`specs/001-apex-mcp-server/`) — Architectural decisions, design rationale

### Step 2: Design Article Structure

Design an article with **6–8 sections** following this narrative arc:

| Phase | Purpose |
|---|---|
| **Opening** | Hook the reader with a concrete problem or provocative observation |
| **Context** | Establish what MCP is and why it matters for Salesforce teams |
| **Architecture** | Walk through the two-layer design with specific code/file references |
| **Developer Experience** | Show how simple it is to build with the framework — code examples |
| **Security** | Explain the four-layer authorization model and why it's a differentiator |
| **Getting Started** | Concrete steps: clone, deploy, connect — with commands and file paths |
| **Closing** | Restate the core value prop; CTA to the repo |

For each section, generate these fields:

- **Section number** (1–N)
- **Heading**: Concise, descriptive section heading
- **Purpose**: 1 sentence — what this section accomplishes in the article arc
- **Key points**: 3–5 bullet points of specific content to include
- **Target word count**: Approximate words for this section (total must sum to 1500–2500)
- **Claims referenced**: List of claim IDs from `claims.md` that ground this section
- **Repo links**: Specific repo files to link/reference (use format `https://github.com/damecek/salesforce-mcp-lib/blob/main/[path]`)
- **Code snippets**: Indicate if this section should include inline code (and which file to excerpt)

### Step 3: Generate Article Metadata

Generate the following metadata for the article:

- **Title**: Compelling, specific article title (not clickbait)
- **Subtitle**: 1-sentence supporting line
- **Target word count**: Total (1500–2500)
- **Target audience**: Primary and secondary audience
- **SEO keywords**: 5–8 keywords for discoverability
- **Hashtags**: 5–6 LinkedIn hashtags (3 fixed: `#Salesforce #MCP #OpenSource` + 2–3 topic-specific)
- **Repo URL**: `https://github.com/damecek/salesforce-mcp-lib`

### Step 4: Validate

Before writing output, verify:

1. **6–8 sections** — no more, no fewer
2. **Total word count target** sums to 1500–2500 across all sections
3. **Every section references at least 1 claim** from `claims.md`
4. **Every section references at least 1 repo file** with a full GitHub URL
5. **Narrative arc is maintained** — opening hooks, context builds, technical deepens, closing converts
6. **At least 3 sections include code snippet indicators**

### Step 5: Write Output

Write the article plan to:

```
specs/002-linkedin-content-system/content/article-plan.md
```

Use this format:

```markdown
# Article Plan: [Title]

**Generated**: [date]
**Source**: Repository analysis of salesforce-mcp-lib
**Repo**: https://github.com/damecek/salesforce-mcp-lib

## Metadata

- **Title**: [title]
- **Subtitle**: [subtitle]
- **Target word count**: [N]
- **Target audience**: [primary] / [secondary]
- **SEO keywords**: [keyword1], [keyword2], ...
- **Hashtags**: [copy-paste line]

## Section 1: [Heading]

- **Purpose**: [1 sentence]
- **Target words**: [N]
- **Key points**:
  - [point 1]
  - [point 2]
  - [point 3]
- **Claims**: [C-XXX, C-YYY]
- **Repo links**:
  - [full GitHub URL 1]
  - [full GitHub URL 2]
- **Code snippet**: [Yes/No — if yes, which file and what to excerpt]

## Section 2: [Heading]

...

## Section N: [Heading]

...

---

## Validation

- Sections: [N] (target: 6–8)
- Total target words: [N] (target: 1500–2500)
- All sections claim-grounded: [YES/NO]
- All sections have repo links: [YES/NO]
- Narrative arc: [opening → context → architecture → DX → security → getting started → closing]
- Code snippet sections: [N] (minimum: 3)
```

## Error Handling

| Condition | Response |
|---|---|
| Missing prerequisite | HARD BLOCK — see Prerequisite Check above |
| User argument conflicts with default structure | Incorporate user input as override; note deviation in output |
| Cannot fill 6 sections with distinct content | Output available sections with a note explaining why fewer were found |
