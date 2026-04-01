---
description: Generate a 5-topic editorial roadmap for a LinkedIn series promoting the Salesforce MCP library
---

## User Input

```text
$ARGUMENTS
```

Consider the user input above (if not empty) as additional context or overrides for topic selection.

## Purpose

Generate a 5-topic editorial roadmap for a LinkedIn series promoting the Salesforce MCP library. The series follows a narrative arc from awareness to adoption.

## Instructions

### Step 1: Scan the Repository

Scan the following 7 repository areas to understand the project's content-worthy themes. Read key files from each area — do not read every file, but sample enough to understand the capabilities, architecture, and value proposition.

1. **Apex MCP framework classes** (`force-app/main/mcp/classes/`) — Framework capabilities, design patterns, developer experience
2. **Apex JSON-RPC core** (`force-app/main/json-rpc/classes/`) — Zero-dependency protocol implementation, strong typing
3. **TypeScript stdio proxy** (`packages/salesforce-mcp-lib/src/`) — OAuth, MCP bridging, stdio transport, zero npm dependencies
4. **Design documentation** (`docs/`) — Wire-contract audit, authorization feasibility report, protocol compliance
5. **Examples** (`examples/`) — Getting-started simplicity, developer experience
6. **Package configuration** (`sfdx-project.json`, `packages/salesforce-mcp-lib/package.json`) — Version history, packaging, distribution
7. **Specs and plans** (`specs/001-apex-mcp-server/`) — Architectural decisions, design rationale

### Step 2: Generate 5 Topics

Synthesize your findings into exactly 5 topics following this narrative arc:

| # | Arc Position | Focus |
|---|---|---|
| 1 | **Awareness** | What this is — introduce the concept and the problem it addresses |
| 2 | **Problem** | The business problem it solves — why existing approaches fall short |
| 3 | **Technical** | How it works technically — architecture, design decisions |
| 4 | **Impact** | Why it matters for teams — organizational and developer experience benefits |
| 5 | **Adoption** | How to use it — getting started, practical next steps |

For each topic, generate these fields:

- **Topic number** (1–5)
- **Title**: Concise, descriptive topic title
- **Core message**: 1–2 sentences — the single key takeaway
- **CTA angle**: 1 sentence — the call-to-action direction
- **Contrarian hook**: 1–2 sentences — a non-obvious or contrarian angle to open with
- **Repo artifact references**: List of specific repo files that support this topic (minimum 1)

### Step 3: Validate

Before writing output, verify:

1. **Exactly 5 topics** — no more, no fewer
2. **No topic overlap >20%** — each topic must cover substantially different ground. If two topics share more than 20% of their conceptual territory, merge or differentiate them.
3. **Every core message maps to at least one repo artifact** — no unsupported claims
4. **Narrative arc is maintained** — topics flow from awareness → adoption

### Step 4: Write Output

Write the series plan to:

```
specs/002-linkedin-content-system/content/series-plan.md
```

Use this format:

```markdown
# Series Plan: Salesforce MCP Library

**Generated**: [date]
**Source**: Repository analysis of salesforce-mcp-lib

## Topic 1: [Title]

**Arc position**: Awareness
**Core message**: [1–2 sentences]
**CTA angle**: [1 sentence]
**Contrarian hook**: [1–2 sentences]
**Repo artifacts**:
- [file path 1]
- [file path 2]

## Topic 2: [Title]

...

## Topic 3: [Title]

...

## Topic 4: [Title]

...

## Topic 5: [Title]

...

---

## Validation

- Topics: [5/5]
- Overlap check: [PASS — no pair exceeds 20% overlap]
- Repo grounding: [PASS — all core messages reference repo artifacts]
- Narrative arc: [awareness → problem → technical → impact → adoption]
```

## Error Handling

| Condition | Response |
|---|---|
| Repository missing or inaccessible | Output: "ERROR: Cannot access repository. Ensure you are in the correct working directory." Stop execution. |
| User argument conflicts with narrative arc | Incorporate user input as override; note deviation from default arc in the output. |
| Cannot identify 5 distinct topics | Output available topics with a note explaining why fewer were found. |
