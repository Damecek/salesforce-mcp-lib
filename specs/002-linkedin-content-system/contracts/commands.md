# Command Contracts: LinkedIn Content System

**Feature**: 002-linkedin-content-system
**Date**: 2026-03-31

## Overview

The content system exposes 5 Claude Code user commands. Each command is a markdown prompt file placed in `.claude/commands/`. Users invoke them via `/<command-name>` in the Claude Code CLI. This document defines the interface contract for each command: inputs, prerequisites, outputs, and error behavior.

---

## Command 1: `/series-plan`

**File**: `.claude/commands/series-plan.md`
**Purpose**: Generate the 5-topic editorial roadmap for the LinkedIn series.

### Input

| Parameter | Source | Required | Description |
|---|---|---|---|
| `$ARGUMENTS` | User input | No | Optional override or additional context for topic selection |

### Prerequisites

None — this is a root command with no dependencies.

### Behavior

1. Scan the repository to identify content-worthy themes:
   - Read `force-app/main/mcp/classes/` for framework capabilities
   - Read `force-app/main/json-rpc/classes/` for protocol implementation
   - Read `packages/salesforce-mcp-lib/src/` for proxy architecture
   - Read `docs/` for design documentation
   - Read `examples/` for developer experience artifacts
   - Read `sfdx-project.json` and `packages/salesforce-mcp-lib/package.json` for packaging info
   - Read `specs/001-apex-mcp-server/` for architectural decisions
2. Synthesize findings into 5 topics following the narrative arc:
   - Topic 1: What this is (awareness)
   - Topic 2: Business problem it solves
   - Topic 3: How it works technically
   - Topic 4: Why it matters for teams
   - Topic 5: How to use it (adoption)
3. For each topic, generate: core message, CTA angle, contrarian hook, repo artifact references.
4. Validate: no two topics share >20% conceptual overlap.

### Output

| Artifact | Path | Format |
|---|---|---|
| Series Plan | `specs/002-linkedin-content-system/content/series-plan.md` | Markdown per data-model.md Series Plan entity |

### Error Behavior

| Condition | Response |
|---|---|
| Repository missing or empty | ERROR: "Cannot access repository at [path]. Ensure you are in the correct working directory." |
| User argument conflicts with narrative arc | Incorporate user input as override; note deviation from default arc in output |

---

## Command 2: `/proof-pack`

**File**: `.claude/commands/proof-pack.md`
**Purpose**: Extract verifiable, repo-grounded factual claims for content use.

### Input

| Parameter | Source | Required | Description |
|---|---|---|---|
| `$ARGUMENTS` | User input | No | Optional focus area or additional context |

### Prerequisites

None — this is a root command with no dependencies.

### Behavior

1. Scan the 7 repository areas identified in research.md (Task 5) in priority order.
2. For each area, extract factual claims: code patterns, design decisions, capability statements, configuration choices.
3. For each claim, record: unique ID, category, statement, source file path, verbatim excerpt, business-value translation.
4. Exclude content from `.env`, credential files, external client app configurations.
5. Organize claims into 6 categories: package-purpose, architecture, developer-experience, security, deployment, differentiation.
6. Validate: at least 15 claims, all 6 categories represented, every claim has a verifiable source.

### Output

| Artifact | Path | Format |
|---|---|---|
| Claims | `specs/002-linkedin-content-system/content/claims.md` | Markdown per data-model.md Proof Pack entity |

### Error Behavior

| Condition | Response |
|---|---|
| Fewer than 15 extractable claims | WARNING: "Only [N] claims extracted. Consider expanding repo documentation or relaxing category requirements." Proceed with available claims. |
| Secret-containing file encountered | SKIP: Silently exclude the file. Log exclusion in a comment at the bottom of claims.md. |

---

## Command 3: `/draft-post`

**File**: `.claude/commands/draft-post.md`
**Purpose**: Generate 3 style variants and 5 opening hooks for a specific series post.

### Input

| Parameter | Source | Required | Description |
|---|---|---|---|
| `$ARGUMENTS` | User input | Yes | Post number (1–5). Example: `/draft-post 3` |

### Prerequisites

| Artifact | Path | Producing Command |
|---|---|---|
| Series Plan | `specs/002-linkedin-content-system/content/series-plan.md` | `/series-plan` |
| Claims | `specs/002-linkedin-content-system/content/claims.md` | `/proof-pack` |

**Hard block**: If either prerequisite is missing, refuse to execute. Output:
```
ERROR: Missing prerequisite.
- [Missing artifact] not found.
- Run `/[command]` first to generate it.
```

### Behavior

1. Read series plan to get topic N's structure (core message, CTA angle, contrarian hook, repo artifacts).
2. Read claims to identify supporting facts for topic N (at least 2 claims).
3. Generate 3 post variants:
   - **Technical**: Precise, architecture-focused. Leads with how the system works.
   - **Business**: Problem-solution, outcome-focused. Leads with the business problem.
   - **Founder/open-source**: Story-driven, community-focused. Leads with the journey.
4. For each variant: ensure 150–300 words, at least 1 repo fact, at least 1 business outcome, no forbidden phrases.
5. Generate 5 opening hooks (pain-first, misconception-first, architecture-first, business-first, curiosity-first), each 2–3 lines.
6. Write all output files.

### Output

| Artifact | Path | Format |
|---|---|---|
| Technical draft | `specs/002-linkedin-content-system/content/posts/post-N/draft-technical.md` | Markdown per data-model.md Post Draft entity |
| Business draft | `specs/002-linkedin-content-system/content/posts/post-N/draft-business.md` | Markdown per data-model.md Post Draft entity |
| Founder draft | `specs/002-linkedin-content-system/content/posts/post-N/draft-founder.md` | Markdown per data-model.md Post Draft entity |
| Hooks | `specs/002-linkedin-content-system/content/posts/post-N/hooks.md` | Markdown per data-model.md Hook Set entity |

### Error Behavior

| Condition | Response |
|---|---|
| Missing prerequisites | HARD BLOCK: See prerequisite section above |
| Post number not 1–5 | ERROR: "Invalid post number '[N]'. Must be 1–5." |
| No `$ARGUMENTS` provided | ERROR: "Post number required. Usage: `/draft-post N` where N is 1–5." |
| Topic has fewer than 2 supporting claims | WARNING: "Topic [N] has only [X] supporting claims. Consider running `/proof-pack` again to expand coverage." Proceed with available claims. |

---

## Command 4: `/comment-bank`

**File**: `.claude/commands/comment-bank.md`
**Purpose**: Generate 20+ pre-written comment replies organized by question category.

### Input

| Parameter | Source | Required | Description |
|---|---|---|---|
| `$ARGUMENTS` | User input | No | Optional additional question categories or focus areas |

### Prerequisites

| Artifact | Path | Producing Command |
|---|---|---|
| Claims | `specs/002-linkedin-content-system/content/claims.md` | `/proof-pack` |

**Hard block**: If prerequisite is missing, refuse to execute.

### Behavior

1. Read claims for factual grounding.
2. Generate replies for at least 6 mandatory categories:
   - "What is MCP?"
   - "Why not Agentforce?"
   - "Why Apex?"
   - "Why local bridge?"
   - "How is auth handled?"
   - "Can this be used in enterprise?"
3. Generate at least 3 reply variants per category, at least 20 total.
4. Each reply: 2–5 sentences, technically accurate, cites repo fact for technical questions.

### Output

| Artifact | Path | Format |
|---|---|---|
| Comment Bank | `specs/002-linkedin-content-system/content/comment-bank.md` | Markdown per data-model.md Comment Bank entity |

### Error Behavior

| Condition | Response |
|---|---|
| Missing prerequisite | HARD BLOCK: "Missing prerequisite. Run `/proof-pack` first." |

---

## Command 5: `/repurpose-post`

**File**: `.claude/commands/repurpose-post.md`
**Purpose**: Transform a completed post draft into 4 derivative formats.

### Input

| Parameter | Source | Required | Description |
|---|---|---|---|
| `$ARGUMENTS` | User input | Yes | Post number (1–5). Example: `/repurpose-post 2` |

### Prerequisites

| Artifact | Path | Producing Command |
|---|---|---|
| Post drafts | `specs/002-linkedin-content-system/content/posts/post-N/draft-*.md` | `/draft-post N` |

**Hard block**: If no draft files exist for the specified post number, refuse to execute.

### Behavior

1. Read all available draft variants for post N.
2. Select the best variant as source (or use the first available).
3. Generate 4 derivative formats:
   - **Short post**: Under 100 words, preserves core message and key repo fact
   - **Carousel script**: 5–8 slides, each with headline + body
   - **Comment version**: 2–3 sentences, usable as a standalone comment
   - **DM explanation**: 3–5 sentences, informal tone, suitable for direct messages
4. Validate: core message and key repo fact preserved in each derivative.

### Output

| Artifact | Path | Format |
|---|---|---|
| Derivatives | `specs/002-linkedin-content-system/content/posts/post-N/derivatives.md` | Markdown per data-model.md Derivatives entity |

### Error Behavior

| Condition | Response |
|---|---|
| Missing prerequisites | HARD BLOCK: "No drafts found for post [N]. Run `/draft-post [N]` first." |
| Post number not 1–5 | ERROR: "Invalid post number '[N]'. Must be 1–5." |
| No `$ARGUMENTS` provided | ERROR: "Post number required. Usage: `/repurpose-post N` where N is 1–5." |
