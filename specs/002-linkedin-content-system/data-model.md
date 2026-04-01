# Data Model: LinkedIn Content System

**Feature**: 002-linkedin-content-system
**Date**: 2026-03-31

## Overview

This feature introduces no compiled code entities — all artifacts are markdown files generated and consumed by Claude Code commands. The "data model" defines the structure, fields, and relationships of these content artifacts, along with validation rules and state transitions.

## Entities

### 1. Series Plan (`content/series-plan.md`)

A single editorial roadmap defining the 5-topic LinkedIn series.

| Field | Type | Required | Description |
|---|---|---|---|
| `title` | Heading | Yes | "Series Plan: [Project Name]" |
| `topics` | Ordered list (5 items) | Yes | Exactly 5 topics, ordered from awareness to adoption |
| `topics[].number` | Integer (1–5) | Yes | Topic sequence number |
| `topics[].title` | String | Yes | Topic title (concise, descriptive) |
| `topics[].core_message` | String (1–2 sentences) | Yes | The single key takeaway for this topic |
| `topics[].cta_angle` | String (1 sentence) | Yes | The call-to-action direction for the post |
| `topics[].contrarian_hook` | String (1–2 sentences) | Yes | A non-obvious or contrarian angle to open with |
| `topics[].repo_artifacts` | List of file paths | Yes | Specific repo files that support this topic (min 1) |
| `topics[].target_claims` | List of claim IDs | No | Populated after `/proof-pack` runs; links to supporting claims |

**Validation Rules**:
- Exactly 5 topics (FR-002)
- No two topics share more than 20% conceptual overlap (FR-004)
- Every core message maps to at least one repo artifact (US-1, scenario 3)
- Topics follow the narrative arc: (1) What this is, (2) Business problem, (3) How it works technically, (4) Why it matters for teams, (5) How to use it

**Relationships**:
- Referenced by: Post Drafts (each draft targets one topic number)
- Referenced by: Hook Sets (hooks are generated per topic)
- References: Repository files (via `repo_artifacts`)

---

### 2. Proof Pack / Claims (`content/claims.md`)

A collection of verifiable factual claims extracted from the repository.

| Field | Type | Required | Description |
|---|---|---|---|
| `title` | Heading | Yes | "Claims: [Project Name]" |
| `categories` | Grouped sections | Yes | Claims organized by category |
| `claims[].id` | String (e.g., `C-001`) | Yes | Unique claim identifier |
| `claims[].category` | Enum | Yes | One of: package-purpose, architecture, developer-experience, security, deployment, differentiation |
| `claims[].statement` | String (1–2 sentences) | Yes | The factual claim in quotable form |
| `claims[].source_file` | Absolute or repo-relative path | Yes | The file this claim is grounded in |
| `claims[].excerpt` | String (code snippet or quote) | Yes | Verbatim excerpt from the source file |
| `claims[].business_value` | String (1 sentence) | Yes | Business-value translation of the technical fact (FR-009) |

**Validation Rules**:
- At least 15 claims (FR-007)
- Every claim cites a specific source file path with excerpt (FR-006)
- All 6 categories represented (FR-007)
- No claims sourced from `.env`, credential files, or files containing secrets (FR-008)
- Every topic in the series plan has at least 2 supporting claims

**Relationships**:
- Referenced by: Post Drafts (factual statements must trace to claims)
- Referenced by: Comment Bank (technical replies cite claims)
- Referenced by: Quality guardrail hooks (claim-check validates against this file)

---

### 3. Post Draft (`content/posts/post-N/draft-{variant}.md`)

A single LinkedIn post in one of three style variants.

| Field | Type | Required | Description |
|---|---|---|---|
| `title` | Heading | Yes | "Post N — {Variant}: {Topic Title}" |
| `topic_number` | Integer (1–5) | Yes | Which series topic this post covers |
| `variant` | Enum | Yes | One of: technical, business, founder |
| `body` | Markdown text | Yes | The full LinkedIn post content |
| `word_count` | Integer | Yes | Computed word count (must be 150–300) |
| `repo_facts` | Inline in body | Yes | At least 1 specific repo fact cited in the post text |
| `business_outcomes` | Inline in body | Yes | At least 1 business outcome stated in the post text |
| `claims_referenced` | List of claim IDs | Yes | Which claims from `claims.md` are used |
| `cta` | Inline in body | Yes | Closing call-to-action |

**Validation Rules**:
- Word count 150–300 (FR-012)
- First 3 lines create curiosity and clarity, no clickbait (FR-013)
- No forbidden phrases: "AI is changing everything," "the future of," "game-changer," "revolutionary," "next-generation" (FR-014)
- At least 1 specific repo fact (FR-011)
- At least 1 business outcome (FR-011)
- All factual claims traceable to `claims.md` entries (FR-022)

**State Transitions**:
- Created by `/draft-post N`
- Validated by `PostToolUse` hooks (claim-check + style-check) on write
- Overwritten on re-run of `/draft-post N`

**Relationships**:
- Depends on: Series Plan (topic structure), Claims (factual grounding)
- Referenced by: Derivatives (repurposed from this draft)
- Co-located with: Hook Set (same `post-N/` directory)

---

### 4. Hook Set (`content/posts/post-N/hooks.md`)

Five opening-line variants for a single post topic.

| Field | Type | Required | Description |
|---|---|---|---|
| `title` | Heading | Yes | "Hooks: Post N — {Topic Title}" |
| `topic_number` | Integer (1–5) | Yes | Which series topic these hooks target |
| `hooks` | List (exactly 5) | Yes | One hook per framing angle |
| `hooks[].framing` | Enum | Yes | One of: pain-first, misconception-first, architecture-first, business-first, curiosity-first |
| `hooks[].text` | String (2–3 lines) | Yes | The opening hook text |
| `hooks[].technical_accuracy` | Boolean (implicit) | Yes | Must be technically accurate (FR-016) |

**Validation Rules**:
- Exactly 5 hooks with 5 distinct framings (FR-015)
- Each hook is 2–3 lines (FR-016)
- Technically accurate — no invented capabilities or false claims
- No generic superlatives or hype language

**Relationships**:
- Depends on: Series Plan (topic), Claims (factual basis)
- Generated within: `/draft-post N` command
- Co-located with: Post Drafts (same `post-N/` directory)

---

### 5. Comment Bank (`content/comment-bank.md`)

Pre-written replies organized by anticipated question category.

| Field | Type | Required | Description |
|---|---|---|---|
| `title` | Heading | Yes | "Comment Bank: [Project Name]" |
| `categories` | Grouped sections | Yes | At least 6 question categories |
| `categories[].name` | String | Yes | The anticipated question (e.g., "What is MCP?") |
| `replies[]` | List (min 3 per category) | Yes | Pre-written reply variants |
| `replies[].text` | String (2–5 sentences) | Yes | The comment reply text |
| `replies[].repo_reference` | String | Conditional | Required for technical questions — cites a repo fact or claim ID |

**Validation Rules**:
- At least 20 total replies (FR-017)
- At least 6 categories: "What is MCP?", "Why not Agentforce?", "Why Apex?", "Why local bridge?", "How is auth handled?", "Can this be used in enterprise?" (FR-018)
- At least 3 replies per category (implied by 20 replies / 6 categories)
- Each reply is 2–5 sentences (FR-019)
- Technical questions include repo fact citation (FR-019)

**Relationships**:
- Depends on: Claims (factual grounding for technical replies)

---

### 6. Derivatives (`content/posts/post-N/derivatives.md`)

Four derivative formats repurposed from a post draft.

| Field | Type | Required | Description |
|---|---|---|---|
| `title` | Heading | Yes | "Derivatives: Post N — {Topic Title}" |
| `topic_number` | Integer (1–5) | Yes | Which series topic |
| `source_variant` | String | Yes | Which draft variant was used as source |
| `short_post` | String (<100 words) | Yes | Condensed version of the post |
| `carousel_script` | Structured list (5–8 slides) | Yes | Each slide has headline + body text |
| `comment_version` | String (2–3 sentences) | Yes | Comment-sized version |
| `dm_explanation` | String (3–5 sentences, informal) | Yes | Direct message version |

**Validation Rules**:
- Short post under 100 words (FR-020)
- Carousel has 5–8 slides (FR-020)
- Comment version is 2–3 sentences (FR-020)
- DM explanation is 3–5 sentences, informal tone (FR-020)
- Core message and key repo fact preserved from original (FR-021)

**Relationships**:
- Depends on: Post Draft (the source content)

---

## Entity Relationship Diagram

```
Repository Files
    │
    ▼
┌──────────────┐     ┌──────────────┐
│ Series Plan  │     │  Proof Pack  │
│ (5 topics)   │     │  (15+ claims)│
└──────┬───────┘     └──────┬───────┘
       │                     │
       ├─────────┬───────────┤
       │         │           │
       ▼         ▼           ▼
┌────────────┐ ┌──────┐ ┌──────────────┐
│ Post Draft │ │ Hook │ │ Comment Bank  │
│ (3 per     │ │ Set  │ │ (20+ replies)│
│  topic)    │ │      │ └──────────────┘
└──────┬─────┘ └──────┘
       │
       ▼
┌──────────────┐
│ Derivatives  │
│ (4 formats)  │
└──────────────┘
```

## File Path Reference

| Entity | Path Pattern | Count |
|---|---|---|
| Series Plan | `specs/002-linkedin-content-system/content/series-plan.md` | 1 |
| Proof Pack | `specs/002-linkedin-content-system/content/claims.md` | 1 |
| Post Draft | `specs/002-linkedin-content-system/content/posts/post-{1-5}/draft-{technical,business,founder}.md` | 15 |
| Hook Set | `specs/002-linkedin-content-system/content/posts/post-{1-5}/hooks.md` | 5 |
| Comment Bank | `specs/002-linkedin-content-system/content/comment-bank.md` | 1 |
| Derivatives | `specs/002-linkedin-content-system/content/posts/post-{1-5}/derivatives.md` | 5 |
| **Total generated content files** | | **27** |
