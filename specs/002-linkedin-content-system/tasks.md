# Tasks: LinkedIn Content System for Salesforce MCP Library

**Input**: Design documents from `/specs/002-linkedin-content-system/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Not requested — no test tasks included.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Command files**: `.claude/commands/<command-name>.md`
- **Hook configuration**: `.claude/settings.json`
- **Content output**: `specs/002-linkedin-content-system/content/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the content output directory structure required by all content-generating commands.

- [ ] T001 Create content output directory tree at `specs/002-linkedin-content-system/content/` including subdirectories `posts/post-1/`, `posts/post-2/`, `posts/post-3/`, `posts/post-4/`, and `posts/post-5/`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: No blocking foundational prerequisites identified for this project.

This feature introduces only Claude Code markdown prompt files (`.claude/commands/*.md`) and JSON configuration (`.claude/settings.json`). Each command file is self-contained. The content output directory (Phase 1) is the only shared prerequisite.

**Checkpoint**: Directory structure ready — user story implementation can now begin.

---

## Phase 3: User Story 1 — Plan the 5-Part LinkedIn Series (Priority: P1) 🎯 MVP

**Goal**: Create the `/series-plan` command that generates a 5-topic editorial roadmap from repository analysis.

**Independent Test**: Run `/series-plan` and verify output contains 5 ordered topics, each with a core message, CTA angle, contrarian hook, and repo artifact references — with no topic overlap.

### Implementation for User Story 1

- [ ] T002 [US1] Create `/series-plan` command prompt at `.claude/commands/series-plan.md` — include repo scanning instructions for 7 areas (Apex MCP framework, JSON-RPC core, TypeScript proxy, design docs, examples, package config, specs per research.md Task 5), 5-topic narrative arc generation (awareness→adoption per spec assumptions), per-topic fields (core message, CTA angle, contrarian hook, repo artifact references per data-model.md Series Plan entity), validation rules (exactly 5 topics, no >20% overlap per FR-002/FR-004), output writing to `specs/002-linkedin-content-system/content/series-plan.md`, and error handling per contracts/commands.md Command 1

**Checkpoint**: `/series-plan` command is functional. Run it to generate `content/series-plan.md` with 5 topics.

---

## Phase 4: User Story 2 — Extract Repo-Grounded Proof for Content Claims (Priority: P1)

**Goal**: Create the `/proof-pack` command that extracts verifiable factual claims from the repository.

**Independent Test**: Run `/proof-pack` and verify output contains 15+ claims across 6 categories, each with source file path and quotable excerpt.

### Implementation for User Story 2

- [ ] T003 [P] [US2] Create `/proof-pack` command prompt at `.claude/commands/proof-pack.md` — include 7-area repo scanning in priority order (per research.md Task 5: Apex MCP classes, JSON-RPC core, TypeScript proxy, design docs, examples, package config, specs), claim extraction with fields per data-model.md Proof Pack entity (ID, category, statement, source file, excerpt, business-value translation per FR-009), secret file exclusion for `.env`/credentials/connected app configs (FR-008), 6-category organization (package-purpose, architecture, developer-experience, security, deployment, differentiation per FR-007), 15+ claim minimum validation, output writing to `specs/002-linkedin-content-system/content/claims.md`, and error handling per contracts/commands.md Command 2

**Checkpoint**: `/proof-pack` command is functional. Run it to generate `content/claims.md` with 15+ grounded claims.

---

## Phase 5: User Story 7 — Quality Guardrails via Automated Hooks (Priority: P2)

**Goal**: Configure automatic quality validation hooks that fire whenever content files are written, verifying claim accuracy and style compliance.

**Independent Test**: Write a test content file to `content/posts/post-1/draft-technical.md` and verify both hooks fire with pass/fail reports.

### Implementation for User Story 7

- [ ] T004 [US7] Add claim-check prompt hook to `.claude/settings.json` — configure `PostToolUse` event with `Write|Edit` matcher, `if` condition scoped to content draft files, hooks.md, and comment-bank.md per contracts/hooks.md Hook 1 trigger conditions, and claim verification prompt that reads the written file + `specs/002-linkedin-content-system/content/claims.md`, identifies every factual statement, verifies each traces to a claim entry, and reports pass/fail with specific ungrounded claims, line numbers, and suggested fixes (FR-022, FR-024)
- [ ] T005 [US7] Add style-check prompt hook to `.claude/settings.json` — configure `PostToolUse` event with `Write|Edit` matcher, `if` condition scoped to draft files only per contracts/hooks.md Hook 2 trigger conditions, and style verification prompt checking 5 criteria: word count 150–300 (FR-012), opening quality without clickbait (FR-013), no forbidden phrases (FR-014), business outcome present (FR-011), repo fact present (FR-011) — with per-criterion pass/fail and suggested fixes (FR-024)

**Checkpoint**: Both hooks are configured in `.claude/settings.json`. Writing a content file under `content/posts/` should trigger automatic validation.

---

## Phase 6: User Story 3 & User Story 4 — Draft Posts with Variants and Opening Hooks (Priority: P2)

**Goal**: Create the `/draft-post` command that generates 3 style variants (US3: technical, business, founder) and 5 opening hooks (US4: pain-first, misconception-first, architecture-first, business-first, curiosity-first) for each series post.

**Depends on**: US1 (series plan) + US2 (claims) at runtime — enforced via prerequisite check in the command prompt.

**Independent Test**: Run `/draft-post 1` and verify output includes 3 variant drafts (each 150–300 words with repo fact and business outcome) plus `hooks.md` with 5 distinct framing angles.

### Implementation for User Stories 3 & 4

- [ ] T006 [US3] Create `/draft-post` command prompt at `.claude/commands/draft-post.md` — include `$ARGUMENTS` parsing for post number (1–5), prerequisite check for `content/series-plan.md` + `content/claims.md` with hard-block error messages per FR-028/FR-029 and contracts/commands.md Command 3, topic extraction from series plan, claim mapping (at least 2 supporting claims per topic), 3-variant generation logic (technical: architecture-focused, business: problem-solution, founder: story-driven per FR-010), per-variant enforcement of 150–300 words (FR-012), at least 1 repo fact + 1 business outcome (FR-011), strong opening line (FR-013), no forbidden phrases (FR-014), output writing to `specs/002-linkedin-content-system/content/posts/post-N/draft-{technical,business,founder}.md`, and all error handling per contracts/commands.md Command 3
- [ ] T007 [US4] Integrate opening hook generation into `/draft-post` command at `.claude/commands/draft-post.md` — add section generating exactly 5 hook variants per data-model.md Hook Set entity (pain-first, misconception-first, architecture-first, business-first, curiosity-first per FR-015), each 2–3 lines and technically accurate (FR-016), no generic superlatives or hype language, output writing to `specs/002-linkedin-content-system/content/posts/post-N/hooks.md`

**Checkpoint**: `/draft-post N` produces 4 files per post (3 drafts + hooks.md). Quality hooks from Phase 5 auto-trigger on each write.

---

## Phase 7: User Story 5 — Build a Comment Reply Bank (Priority: P3)

**Goal**: Create the `/comment-bank` command that generates 20+ pre-written comment replies covering predictable questions and objections.

**Depends on**: US2 (claims) at runtime — enforced via prerequisite check.

**Independent Test**: Run `/comment-bank` and verify output contains 20+ replies across 6+ categories, each 2–5 sentences with repo fact citations for technical questions.

### Implementation for User Story 5

- [ ] T008 [P] [US5] Create `/comment-bank` command prompt at `.claude/commands/comment-bank.md` — include prerequisite check for `content/claims.md` with hard-block error per FR-028/FR-029 and contracts/commands.md Command 4, claims reading for factual grounding, reply generation for 6 mandatory categories ("What is MCP?", "Why not Agentforce?", "Why Apex?", "Why local bridge?", "How is auth handled?", "Can this be used in enterprise?" per FR-018), at least 3 reply variants per category totaling 20+ replies (FR-017), each reply 2–5 sentences (FR-019) with repo fact citation for technical questions (FR-019), output writing to `specs/002-linkedin-content-system/content/comment-bank.md`, and error handling per contracts/commands.md Command 4

**Checkpoint**: `/comment-bank` produces `content/comment-bank.md` with 20+ organized replies across 6+ categories.

---

## Phase 8: User Story 6 — Repurpose Posts into Multiple Formats (Priority: P3)

**Goal**: Create the `/repurpose-post` command that transforms any drafted post into 4 derivative formats for multi-channel distribution.

**Depends on**: US3 (post drafts for specified post number) at runtime — enforced via prerequisite check.

**Independent Test**: Run `/repurpose-post 1` after drafting post 1 and verify output contains all 4 derivative formats preserving core message and key repo fact.

### Implementation for User Story 6

- [ ] T009 [P] [US6] Create `/repurpose-post` command prompt at `.claude/commands/repurpose-post.md` — include `$ARGUMENTS` parsing for post number (1–5), prerequisite check for `content/posts/post-N/draft-*.md` with hard-block error per FR-028/FR-029 and contracts/commands.md Command 5, draft reading (select best or first available variant as source), 4-derivative generation per data-model.md Derivatives entity (short post under 100 words, carousel script 5–8 slides with headline + body, comment version 2–3 sentences, DM explanation 3–5 sentences informal per FR-020), core message + key repo fact preservation validation (FR-021), output writing to `specs/002-linkedin-content-system/content/posts/post-N/derivatives.md`, and error handling per contracts/commands.md Command 5

**Checkpoint**: `/repurpose-post N` produces `content/posts/post-N/derivatives.md` with 4 derivative formats.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: End-to-end validation of the complete content workflow.

- [ ] T010 Validate complete dependency chain by executing commands in order: `/series-plan` → `/proof-pack` → `/draft-post 1` → `/comment-bank` → `/repurpose-post 1` — verify each command enforces prerequisites, produces correct output at the expected path, and quality hooks fire for draft and hook files
- [ ] T011 [P] Verify hard-block prerequisite enforcement by running `/draft-post 1` without `content/series-plan.md`, `/repurpose-post 1` without drafts, and `/comment-bank` without `content/claims.md` — confirm each command refuses to execute with a clear error naming the missing artifact and producing command
- [ ] T012 [P] Run quickstart.md verification checklist at `specs/002-linkedin-content-system/quickstart.md` — confirm all 6 verification steps pass (series plan, proof pack, draft with hooks, hard-block test, comment bank, repurpose)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: No blocking prerequisites identified
- **US1 (Phase 3)**: Depends on Setup only — can start immediately
- **US2 (Phase 4)**: Depends on Setup only — can start immediately, **parallel with US1**
- **US7 (Phase 5)**: Depends on Setup only — can start in parallel with US1/US2, but should complete before US3/US4 to ensure hooks are active during content generation
- **US3 & US4 (Phase 6)**: Depends on US1 + US2 (runtime) + US7 (hooks should be active)
- **US5 (Phase 7)**: Depends on US2 (runtime) — can start after US2, **parallel with US3/US4**
- **US6 (Phase 8)**: Depends on US3 (runtime) — can start after any post is drafted
- **Polish (Phase 9)**: Depends on all previous phases complete

### User Story Dependencies

- **US1 (P1)**: Independent — no dependencies on other stories
- **US2 (P1)**: Independent — no dependencies on other stories, [P] with US1
- **US7 (P2)**: Independent — no story dependencies, but should be configured before US3/US4
- **US3 & US4 (P2)**: Depends on US1 (series plan) + US2 (claims) at command runtime
- **US5 (P3)**: Depends on US2 (claims) at command runtime
- **US6 (P3)**: Depends on US3 (post drafts) at command runtime

### Within Each User Story

- Each story produces one command file (`.claude/commands/*.md`) or one configuration update (`.claude/settings.json`)
- No model→service→endpoint progression — pure markdown prompts
- Each command file is written as a complete, self-contained unit
- Quality hooks (US7) should be in place before content-generating commands are tested

### Parallel Opportunities

- **US1 + US2** (Phases 3–4): Both P1, no shared files — fully parallel
- **US7 + US1 + US2** (Phases 3–5): All independent files — can run concurrently
- **US5 + US6** (Phases 7–8): Different command files — parallel after dependencies met
- **T011 + T012** (Polish): Independent validation activities — parallel

---

## Parallel Example: US1 + US2 (P1 Stories)

```
# Both P1 stories target different files — implement simultaneously:
Task T002: "Create /series-plan command at .claude/commands/series-plan.md"
Task T003: "Create /proof-pack command at .claude/commands/proof-pack.md"
```

## Parallel Example: US5 + US6 (P3 Stories)

```
# Both P3 stories target different files — implement simultaneously:
Task T008: "Create /comment-bank command at .claude/commands/comment-bank.md"
Task T009: "Create /repurpose-post command at .claude/commands/repurpose-post.md"
```

---

## Implementation Strategy

### MVP First (User Stories 1 & 2 Only)

1. Complete Phase 1: Setup (directory structure)
2. Complete Phase 3: US1 — `/series-plan` command
3. Complete Phase 4: US2 — `/proof-pack` command
4. **STOP and VALIDATE**: Run both commands, verify output quality
5. The maintainer now has a series plan and proof pack — immediate content value

### Incremental Delivery

1. Setup → US1 + US2 → Foundation content exists (series plan + claims)
2. Add US7 → Quality guardrails active
3. Add US3 + US4 → Full post drafting with hooks and auto-validation
4. Add US5 → Comment bank ready for post engagement
5. Add US6 → Repurposing extends content reach across LinkedIn interaction modes
6. Polish → End-to-end validation confirms complete workflow

### Parallel Strategy

With multiple agents or developers:
1. All complete Setup together
2. Once Setup is done:
   - Agent A: US1 (series-plan) → US3/US4 (draft-post)
   - Agent B: US2 (proof-pack) → US5 (comment-bank) → US6 (repurpose-post)
   - Agent C: US7 (hooks configuration) → Polish (validation)
3. Stories complete and integrate via shared content directory

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [Story] label maps task to specific user story for traceability
- Each command file is a self-contained markdown prompt (~50–150 lines of LLM instructions)
- No compiled code, no tests, no external dependencies — pure markdown and JSON
- All quality validation is via LLM-evaluated prompt hooks in `.claude/settings.json`, not scripts
- Commands enforce dependency ordering at runtime via inline prerequisite checks
- Re-running any command overwrites its output file in place; git preserves history
- Total content output: ~27 generated markdown files across the `content/` directory tree
