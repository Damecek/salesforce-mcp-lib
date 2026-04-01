# Implementation Plan: LinkedIn Content System for Salesforce MCP Library

**Branch**: `002-linkedin-content-system` | **Date**: 2026-03-31 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/002-linkedin-content-system/spec.md`

## Summary

Implement a pure Claude Code prompt-based content system (commands, hooks) that produces a repo-grounded, 5-part LinkedIn series promoting the Salesforce MCP library. The system consists of 5 Claude Code user commands (markdown prompt files under `.claude/commands/`) and 2 prompt-type hooks (configured in `.claude/settings.json`) that auto-validate content on write. All logic — series planning, proof extraction, post drafting, hook generation, comment banking, repurposing, and quality guardrails — lives in LLM-evaluated markdown prompts. No TypeScript, shell scripts, or compiled code is introduced. Generated content artifacts are stored under `specs/002-linkedin-content-system/content/`.

## Technical Context

**Language/Version**: Claude Code markdown prompts (no compiled language; LLM-evaluated prompt files only)
**Primary Dependencies**: Claude Code runtime (commands, hooks, file I/O tools). Zero external dependencies.
**Storage**: Filesystem — all content artifacts are markdown files under `specs/002-linkedin-content-system/content/`
**Testing**: Manual validation by maintainer + automated prompt-type hooks that verify content quality on every write
**Target Platform**: Claude Code CLI environment (macOS/Linux)
**Project Type**: Content authoring toolkit (Claude Code command suite)
**Performance Goals**: Complete 5-post series (with variants) in under 2 hours of active maintainer work (SC-001)
**Constraints**: Pure markdown prompts only (no TypeScript/shell scripts per spec assumption). All claims must trace to repository artifacts. Content files overwrite in place (git preserves history). Commands enforce hard dependency ordering.
**Scale/Scope**: 5 command files (`.claude/commands/*.md`), 2 hook configurations in `.claude/settings.json`, ~15 generated content files across `content/` directory tree

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle I: AI-Agent-First Development

| Requirement | Status | Evidence |
|---|---|---|
| Descriptive, consistent file/directory naming | PASS | Commands follow `content-*.md` naming convention under `.claude/commands/`. Content outputs follow spec-defined directory layout (`series-plan.md`, `claims.md`, `posts/post-N/draft-*.md`). |
| Public interfaces include documentation comments | PASS | Each command file includes a purpose section, prerequisite check, and usage instructions that serve as inline documentation for the LLM. |
| Explicit, linear control flow | PASS | Each command is a sequential prompt: check prerequisites → read inputs → generate output → write file. No branching or recursive logic. |
| Meaningful commit messages | PASS | Enforced by constitution governance; no change to commit workflow. |

### Principle II: Agent-Consumable APIs

| Requirement | Status | N/A Justification or Evidence |
|---|---|---|
| Strict JSON-RPC 2.0 / MCP compliance | N/A | This feature introduces no protocol-layer code. All artifacts are markdown prompts and content files. |
| Structured, typed error codes | N/A | Commands produce markdown content, not machine-parseable API responses. Errors are human-readable messages (e.g., "Missing prerequisite: run `/series-plan` first"). |
| Complete JSON Schema descriptors | N/A | No tools, resources, or prompts are added to the MCP server. |
| Standards-compliant message framing | N/A | No stdio or network communication introduced. |

**Note**: Principle II is structurally inapplicable to this feature. The content system is an internal authoring toolkit, not a machine-consumed API surface. No violation.

### Principle III: Maintainability & Reusability

| Requirement | Status | Evidence |
|---|---|---|
| Standalone, no external assumptions | PASS | Commands rely only on the repository being present at the working directory. No org-specific configuration, no external services. |
| Zero production dependencies | PASS | Pure markdown files. No npm packages, no pip installs, no binary dependencies. |
| Single-responsibility modules | PASS | Each command file serves exactly one purpose: `/series-plan` plans, `/proof-pack` extracts, `/draft-post` drafts, etc. Hooks are scoped to one validation domain each (claims, style). |
| Shared types in dedicated locations | N/A | No type definitions introduced. Content format contracts documented in data-model.md serve an analogous role. |

### Principle IV: Strong Typing

| Requirement | Status | N/A Justification or Evidence |
|---|---|---|
| Typed parameters | N/A | No Apex or TypeScript code introduced. Commands accept a single string argument (post number) where applicable. |
| TypeScript interfaces, no `any` | N/A | No TypeScript code in this feature. |
| JSON Schema for tool inputs | N/A | No MCP tools added. |
| Specific error classes | N/A | No compiled error handling. Commands output human-readable error text. |

**Note**: Principle IV is structurally inapplicable. This feature introduces zero compiled code. No violation.

**Gate Result**: PASS — Principles I and III fully satisfied. Principles II and IV are structurally inapplicable (no protocol code, no compiled code).

## Project Structure

### Documentation (this feature)

```text
specs/002-linkedin-content-system/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
.claude/
├── commands/                                # User-invokable Claude Code commands
│   ├── series-plan.md                      # /series-plan — generate 5-topic editorial roadmap
│   ├── proof-pack.md                       # /proof-pack — extract repo-grounded claims
│   ├── draft-post.md                       # /draft-post N — generate 3 variants + hooks for post N
│   ├── comment-bank.md                     # /comment-bank — generate 20+ comment replies
│   └── repurpose-post.md                   # /repurpose-post N — generate 4 derivative formats
├── settings.json                           # Hook configurations (claim-check + style-check)
└── settings.local.json                     # (unchanged — user-specific overrides)

specs/002-linkedin-content-system/
├── content/                                # All generated content artifacts
│   ├── series-plan.md                      # 5-topic editorial roadmap
│   ├── claims.md                           # 15+ repo-grounded factual claims
│   ├── comment-bank.md                     # 20+ pre-written comment replies
│   └── posts/                              # Per-post content
│       ├── post-1/
│       │   ├── draft-technical.md          # Technical variant
│       │   ├── draft-business.md           # Business variant
│       │   ├── draft-founder.md            # Founder/open-source variant
│       │   ├── hooks.md                    # 5 opening hook variants
│       │   └── derivatives.md              # 4 repurposed formats
│       ├── post-2/
│       ├── post-3/
│       ├── post-4/
│       └── post-5/
│           └── (same structure as post-1)
└── spec.md, plan.md, ...                   # Design artifacts
```

**Structure Decision**: No traditional source code directories are needed. This feature introduces only Claude Code configuration files (`.claude/commands/*.md`, `.claude/settings.json`) and generated content files under the existing spec directory. The content output directory (`specs/002-linkedin-content-system/content/`) follows the layout defined in the spec's Key Entities section. This approach keeps all content system artifacts co-located with their specification and avoids polluting the library's source tree.

## Post-Phase 1 Constitution Re-Check

| Principle | Status | Post-Design Evidence |
|---|---|---|
| I. AI-Agent-First Development | PASS | All command files follow descriptive naming (`series-plan.md`, `proof-pack.md`, `draft-post.md`). Content output paths are predictable and documented in data-model.md. Contracts include complete input/output specs with error behavior. Quickstart follows linear step-by-step flow. |
| II. Agent-Consumable APIs | N/A | No protocol code, tools, or machine-consumed APIs introduced. Content system is a human-facing authoring toolkit operated through Claude Code commands. |
| III. Maintainability & Reusability | PASS | Each command is a single-purpose file with no cross-dependencies between command prompts. Hook configuration is centralized in one settings.json entry. Content output directory is self-contained under the spec directory. All artifacts are markdown — no binary dependencies. |
| IV. Strong Typing | N/A | No compiled code introduced. Content artifact structure is documented in data-model.md, serving as a "type contract" for markdown entities. |

**Post-Design Gate Result**: PASS — no new violations introduced by Phase 1 design artifacts. The design is fully aligned with applicable constitution principles.

## Complexity Tracking

> No constitution violations to justify. Principles II and IV are structurally inapplicable (documented in Constitution Check above), which is not a violation — it is an expected outcome when a feature introduces no compiled code or protocol-layer changes.
