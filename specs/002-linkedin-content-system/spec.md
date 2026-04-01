# Feature Specification: LinkedIn Content System for Salesforce MCP Library

**Feature Branch**: `002-linkedin-content-system`
**Created**: 2026-03-31
**Status**: Draft
**Input**: User description: "Build a Claude Code content system (skills, commands, hooks) to produce a repo-grounded, 5-part LinkedIn series promoting the Salesforce MCP library — with post drafts, proof packs, comment banks, and quality guardrails."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Plan the 5-Part LinkedIn Series (Priority: P1)

As the project maintainer, I want to generate a structured series plan that divides the repository's value proposition into 5 distinct, non-overlapping content pillars ordered from awareness to adoption, so that I have a clear editorial roadmap before writing any posts.

**Why this priority**: Without a coherent series structure, individual posts risk overlapping, missing key messages, or being published in an order that confuses the audience. The plan is the foundation everything else depends on.

**Independent Test**: Can be fully tested by running `/series-plan` and verifying the output contains 5 ordered topics, each with a single core message, a CTA angle, and a contrarian hook — with no topic overlap.

**Acceptance Scenarios**:

1. **Given** the repository exists with its current structure and documentation, **When** the maintainer runs `/series-plan`, **Then** the system produces a `series-plan.md` file containing exactly 5 topics ordered from awareness to adoption, each with a core message, CTA angle, and contrarian hook.
2. **Given** a completed series plan, **When** the maintainer reviews the 5 topics side by side, **Then** no two topics share more than 20% conceptual overlap (each addresses a distinct facet of the project).
3. **Given** the series plan, **When** the maintainer checks each topic against the repository, **Then** every core message maps to at least one concrete repo artifact (source file, spec section, example, or architectural decision).

---

### User Story 2 - Extract Repo-Grounded Proof for Content Claims (Priority: P1)

As the project maintainer, I want to extract verifiable facts, code references, and architectural decisions from the repository and organize them into a claims document, so that every statement in a LinkedIn post can be traced back to a real source.

**Why this priority**: Equal to Story 1 because content without grounded proof becomes generic marketing. The proof pack must exist before posts are drafted to prevent hallucinated claims.

**Independent Test**: Can be fully tested by running `/proof-pack` and verifying each claim includes a source file path and a quotable excerpt from the repository.

**Acceptance Scenarios**:

1. **Given** the repository with its Apex framework, TypeScript proxy, examples, and specs, **When** the maintainer runs `/proof-pack`, **Then** the system produces a `claims.md` file with at least 15 factual claims, each citing a specific source file and relevant excerpt.
2. **Given** a completed claims file, **When** the maintainer cross-references any claim against the cited source file, **Then** the claim accurately reflects the content of that file.
3. **Given** the claims file, **When** the maintainer maps claims to the 5 series topics, **Then** every topic has at least 2 supporting claims available.

---

### User Story 3 - Draft LinkedIn Posts with Multiple Variants (Priority: P2)

As the project maintainer, I want to generate 3 style variants (technical, business, founder/open-source) for each of the 5 series posts, so that I can choose the voice that best fits my audience and moment.

**Why this priority**: Drafting posts is the core deliverable, but it depends on the series plan (Story 1) and proof pack (Story 2) being available first.

**Independent Test**: Can be fully tested by running `/draft-post 1` through `/draft-post 5` and verifying each produces 3 variants plus hook variants, all grounded in claims from the proof pack.

**Acceptance Scenarios**:

1. **Given** a completed series plan and proof pack, **When** the maintainer runs `/draft-post N` (where N is 1–5), **Then** the system produces 3 post variants (technical, business, founder/open-source), each containing a strong opening line, short paragraphs, at least one specific repo fact, and at least one business outcome.
2. **Given** a drafted post variant, **When** the maintainer checks each factual claim in the post, **Then** every claim traces back to an entry in `claims.md`.
3. **Given** a drafted post, **When** the maintainer reviews the first 3 lines, **Then** they create curiosity and clarity without resorting to clickbait or generic "AI is changing everything" phrasing.
4. **Given** a drafted post, **When** the maintainer measures word count, **Then** the post falls within 150–300 words (LinkedIn optimal range for engagement).

---

### User Story 4 - Generate Opening Hooks (Priority: P2)

As the project maintainer, I want to receive 5 hook variants (pain-first, misconception-first, architecture-first, business-first, and curiosity-first) for each post, so that I can A/B test the opening that drives the most engagement.

**Why this priority**: The opening 2–3 lines determine whether LinkedIn shows the rest of the post. This is a high-leverage optimization that runs alongside post drafting.

**Independent Test**: Can be fully tested by generating hooks for any single post topic and verifying each hook uses a distinct framing angle.

**Acceptance Scenarios**:

1. **Given** a series topic and its associated claims, **When** hook generation runs, **Then** the system produces exactly 5 hook variants, each using a different framing approach (pain, misconception, architecture, business, curiosity).
2. **Given** a generated hook, **When** the maintainer reads it, **Then** the hook is 2–3 lines, technically accurate, and does not use generic superlatives or hype language.

---

### User Story 5 - Build a Comment Reply Bank (Priority: P3)

As the project maintainer, I want a pre-written bank of at least 20 comment replies covering predictable questions and objections, so that I can respond quickly and consistently when posts generate discussion.

**Why this priority**: Post engagement happens in comments. Having prepared replies for common questions ("What is MCP?", "Why not Agentforce?", "Why Apex?", "How is auth handled?", "Can this be used in enterprise?", "Why local bridge?") extends the content's reach and demonstrates expertise.

**Independent Test**: Can be fully tested by running `/comment-bank` and verifying it covers the 6 core question categories with at least 3 replies each.

**Acceptance Scenarios**:

1. **Given** the repository and its positioning, **When** the maintainer runs `/comment-bank`, **Then** the system produces at least 20 comment replies organized by question category.
2. **Given** a comment reply about a technical topic (e.g., "Why Apex?"), **When** the maintainer reviews it, **Then** the reply cites at least one specific architectural decision or code reference from the repo.
3. **Given** a comment reply, **When** the maintainer measures its length, **Then** it is 2–5 sentences — concise enough for a LinkedIn comment thread.

---

### User Story 6 - Repurpose Posts into Multiple Formats (Priority: P3)

As the project maintainer, I want to transform any drafted post into derivative formats (short post, carousel script, comment-sized version, DM explanation), so that I can distribute content across multiple LinkedIn interaction modes.

**Why this priority**: Repurposing multiplies the value of each drafted post. It is lower priority because the primary posts must exist first, and not every post needs all format derivatives.

**Independent Test**: Can be fully tested by running `/repurpose-post N` on any completed draft and verifying it produces all 4 derivative formats.

**Acceptance Scenarios**:

1. **Given** a completed post draft, **When** the maintainer runs `/repurpose-post N`, **Then** the system produces 4 derivatives: short post (under 100 words), carousel script (5–8 slides with headline + body), comment version (2–3 sentences), and DM explanation (informal, 3–5 sentences).
2. **Given** a derivative format, **When** the maintainer compares it to the original post, **Then** the core message and key repo fact are preserved.

---

### User Story 7 - Quality Guardrails via Automated Hooks (Priority: P2)

As the project maintainer, I want every drafted post to be automatically checked against style rules, claim accuracy, length limits, and opening quality, so that no draft goes out without meeting baseline quality standards.

**Why this priority**: Without guardrails, content drifts toward generic marketing or makes ungrounded claims. Automated checks ensure consistency across all 5 posts and all variants.

**Independent Test**: Can be fully tested by running a hook on any draft and verifying it produces a pass/fail report with specific issues cited.

**Acceptance Scenarios**:

1. **Given** a drafted post, **When** the claim-check hook runs, **Then** every factual statement in the post is verified against `claims.md` and ungrounded claims are flagged with their location in the text.
2. **Given** a drafted post, **When** the style-check hook runs, **Then** it verifies: word count is 150–300, first 3 lines create curiosity without clickbait, no "AI is changing everything" or similar generic phrasing, at least one business outcome is stated, and at least one specific repo fact is included.
3. **Given** a hook failure, **When** the maintainer reviews the report, **Then** each failure includes the specific text that triggered it and a suggested fix.

---

### Edge Cases

- What happens when the repository structure changes significantly between series plan creation and post drafting? The proof pack should be re-runnable, and posts should reference the latest repo state.
- How does the system handle claims that reference deleted or renamed files? The claim-check hook should flag stale references.
- What happens when a post topic has fewer than 2 supporting claims in the proof pack? The system should warn the maintainer and suggest expanding the proof pack or adjusting the topic.
- How does the system handle the project maintainer providing additional context or corrections mid-series? Commands should accept optional user input that overrides or supplements repo-extracted information.
- What happens if the repo contains sensitive information (client secrets in test fixtures, internal org URLs)? The proof extractor must exclude content from `.env`, credential files, and test fixtures containing secrets.
- What happens when a content command is re-run (e.g., `/draft-post 3` a second time)? The system overwrites the previous output file in place. Git history preserves prior versions; no in-system versioning or archiving is performed.

## Requirements *(mandatory)*

### Functional Requirements

#### Series Planning

- **FR-001**: System MUST analyze the repository structure, documentation, specs, examples, and architectural decisions to identify content-worthy themes.
- **FR-002**: System MUST produce a series plan with exactly 5 topics ordered from awareness (what this is) to adoption (how to use it).
- **FR-003**: Each topic in the series plan MUST include: a single core message, a CTA angle, and a contrarian hook.
- **FR-004**: System MUST ensure no two topics in the series overlap by more than 20% in conceptual scope.

#### Proof Extraction

- **FR-005**: System MUST scan the repository's source files, specs, examples, configuration, and documentation to extract verifiable factual claims.
- **FR-006**: Each extracted claim MUST cite a specific source file path and include a quotable excerpt.
- **FR-007**: System MUST produce at least 15 claims covering: package purpose, architecture decisions, developer experience, security model, deployment model, and differentiation from alternatives.
- **FR-008**: System MUST exclude content from files likely containing secrets (`.env`, `credentials.json`, external client app configurations with real consumer keys).
- **FR-009**: System MUST translate technical repo facts into business-value statements: OAuth client credentials becomes "secure enterprise authentication," zero npm dependencies becomes "minimal supply-chain risk," Apex framework becomes "reusable integration foundation."

#### Post Drafting

- **FR-010**: System MUST generate 3 style variants per post: technical (precise, architecture-focused), business (problem-solution, outcome-focused), and founder/open-source (story-driven, community-focused).
- **FR-011**: Every post variant MUST include at least one specific repo fact and at least one business outcome.
- **FR-012**: Every post variant MUST be 150–300 words.
- **FR-013**: Every post variant MUST open with a strong first line that creates curiosity and clarity.
- **FR-014**: System MUST NOT use generic AI hype phrasing including but not limited to: "AI is changing everything," "the future of," "game-changer," "revolutionary," "next-generation."

#### Hook Generation

- **FR-015**: System MUST generate exactly 5 hook variants per post topic, each using a distinct framing: pain-first, misconception-first, architecture-first, business-first, and curiosity-first.
- **FR-016**: Each hook MUST be 2–3 lines and technically accurate.

#### Comment Bank

- **FR-017**: System MUST generate at least 20 pre-written comment replies organized by question category.
- **FR-018**: System MUST cover at minimum these 6 question categories: "What is MCP?", "Why not Agentforce?", "Why Apex?", "Why local bridge?", "How is auth handled?", "Can this be used in enterprise?"
- **FR-019**: Each comment reply MUST be 2–5 sentences and cite at least one specific repo fact for technical questions.

#### Repurposing

- **FR-020**: System MUST transform any post draft into 4 derivative formats: short post (under 100 words), carousel script (5–8 slides), comment version (2–3 sentences), and DM explanation (3–5 informal sentences).
- **FR-021**: Each derivative MUST preserve the core message and key repo fact from the original post.

#### Quality Guardrails

- **FR-022**: System MUST automatically verify every factual claim in a draft against the proof pack (`claims.md`) and flag ungrounded claims.
- **FR-023**: System MUST automatically check every draft for: word count (150–300), opening quality (curiosity without clickbait), absence of forbidden phrases, presence of a business outcome, and presence of a repo fact.
- **FR-024**: Every quality check failure MUST include the specific text that triggered the failure and a suggested fix.
- **FR-025-GR**: Quality guardrails MUST be implemented as Claude Code hooks (`afterWrite` events in `.claude/settings.json`) that auto-trigger whenever a content file under `specs/002-linkedin-content-system/content/` is written. There is no separate manual quality-check command; all validation runs automatically on write.

#### Content Rules (Enforced Across All Outputs)

- **FR-025**: Target audience is Salesforce developers, architects, AI builders, and technical founders. All content MUST be written for this audience.
- **FR-026**: Tone MUST be direct, technical, and free of marketing fluff.
- **FR-027**: System MUST NOT generate content claims that cannot be traced to the repository.

#### Command Dependency Enforcement

- **FR-028**: Each content command MUST check for required prerequisite artifacts before executing. If a prerequisite is missing, the command MUST hard-block (refuse to run) and display an error naming the missing artifact and the command to produce it.
- **FR-029**: Dependency chain: `/series-plan` has no prerequisites → `/proof-pack` has no prerequisites → `/draft-post N` requires both `series-plan.md` and `claims.md` → `/repurpose-post N` requires the corresponding `post-N/` drafts → `/comment-bank` requires `claims.md`. Hook generation runs within `/draft-post` and shares its prerequisites.

### Key Entities

All generated content artifacts are stored under `specs/002-linkedin-content-system/content/`. Directory layout:

```
specs/002-linkedin-content-system/content/
├── series-plan.md
├── claims.md
├── comment-bank.md
├── posts/
│   ├── post-1/          (one directory per series topic)
│   │   ├── draft-technical.md
│   │   ├── draft-business.md
│   │   ├── draft-founder.md
│   │   ├── hooks.md
│   │   └── derivatives.md
│   ├── post-2/
│   └── ...post-5/
```

- **Series Plan**: The 5-topic editorial roadmap with ordering, core messages, CTAs, and hooks. One per content campaign. Stored as `content/series-plan.md`.
- **Proof Pack**: Collection of verifiable claims extracted from the repository, each with source file citation and excerpt. One per campaign. Stored as `content/claims.md`.
- **Post Draft**: A LinkedIn post in one of 3 style variants (technical, business, founder), associated with a series topic number (1–5). Stored as `content/posts/post-N/draft-{variant}.md`.
- **Hook Set**: 5 opening-line variants for a single post topic, each using a distinct framing angle. Stored as `content/posts/post-N/hooks.md`.
- **Comment Bank**: Organized collection of pre-written replies grouped by anticipated question category. One per campaign. Stored as `content/comment-bank.md`.
- **Derivative Format**: A repurposed version of a post draft in one of 4 formats (short, carousel, comment, DM). Stored as `content/posts/post-N/derivatives.md`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Maintainer can go from zero content to a complete 5-post series (with 3 variants each) in under 2 hours of active work using the commands.
- **SC-002**: 100% of factual claims in published posts trace back to a cited source in the proof pack — zero ungrounded claims pass quality checks.
- **SC-003**: Every post draft passes automated style and claim checks on first or second iteration (no more than 1 revision cycle needed per post).
- **SC-004**: The comment bank covers at least 80% of questions received in the first 48 hours after each post is published (measured by whether a prepared reply addresses the question).
- **SC-005**: Each post in the series generates at least 2x the engagement (reactions + comments) compared to unprompted posts from the same account, indicating the content resonates with the target audience.
- **SC-006**: At least 3 of the 5 posts drive measurable traffic to the repository (clicks on the repo link), demonstrating the series moves readers from awareness toward adoption.
- **SC-007**: Maintainer can generate a complete comment bank in under 10 minutes using `/comment-bank`.

## Assumptions

- The repository at `/Users/adam/IdeaProjects/salesforce-mcp-lib` is the single source of truth for all content claims. No external marketing materials or slide decks are used as source.
- The maintainer publishes on LinkedIn as an individual (personal profile), not a company page. Post formatting targets personal-profile algorithms and display.
- The target audience has baseline familiarity with Salesforce but may not know what MCP (Model Context Protocol) is. Posts must bridge this knowledge gap.
- Agentforce is the primary competitive reference point. The content system must be able to articulate differentiation clearly without being adversarial.
- The 5-post series is published over 2–3 weeks (roughly 2 posts per week) to maintain momentum without overwhelming followers.
- All content is written in English. The maintainer may manually translate or adapt for other languages.
- The series plan follows a fixed narrative arc: (1) What this is, (2) Business problem it solves, (3) How it works technically, (4) Why it matters for teams, (5) How to use it.
- Claude Code is the primary authoring environment. All skills, commands, and hooks operate within the Claude Code workflow and do not require external tools beyond the repository and standard CLI.
- The entire content system is implemented as pure Claude Code markdown prompt files (`.claude/commands/*.md`, `.claude/skills/*.md`, hook definitions in `.claude/settings.json`). No TypeScript scripts, shell scripts, or compiled code components are introduced. All logic — including quality guardrails, claim verification, and style checks — relies on LLM reasoning within markdown prompts.
- Post engagement metrics (SC-005, SC-006) are measured manually by the maintainer after publication. The content system does not include analytics integration.

## Clarifications

### Session 2026-03-31

- Q: How should this content system be implemented — as pure Claude Code markdown prompts or with TypeScript/shell script components? → A: Pure markdown — all skills, commands, and hooks are markdown prompt files only (no TypeScript/shell scripts).
- Q: Where should generated content artifacts be stored? → A: Feature spec directory: `specs/002-linkedin-content-system/content/` (co-located with spec, plan, tasks).
- Q: Should quality guardrail hooks run automatically or only when the user explicitly invokes a check command? → A: Auto-only — Claude Code hooks in settings.json auto-trigger after every content file write; no manual command.
- Q: When a content command is re-run, should it overwrite the previous output or preserve it? → A: Overwrite — always replace with latest; git history preserves prior versions.
- Q: Should commands enforce dependency ordering or allow execution with a warning? → A: Hard-block — refuse to run and tell the user which prerequisite command to run first.
