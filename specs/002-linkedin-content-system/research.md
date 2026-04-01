# Research: LinkedIn Content System

**Feature**: 002-linkedin-content-system
**Date**: 2026-03-31
**Status**: Complete

## Research Task 1: Claude Code Hook Mechanism for Quality Guardrails

**Context**: FR-025-GR requires quality guardrails implemented as hooks that auto-trigger when content files are written. The spec originally references "afterWrite events" but Claude Code uses a different event model.

### Decision: Use `PostToolUse` event with `type: "prompt"` hooks

### Rationale

Claude Code does not have a dedicated `afterWrite` event. The correct mechanism is:

- **Event**: `PostToolUse` — fires after a tool (Write, Edit) completes successfully.
- **Matcher**: `"Write|Edit"` — regex that matches both the Write and Edit tool names.
- **File filtering**: The `if` field supports permission-rule syntax with glob patterns, e.g., `Write(specs/002-linkedin-content-system/content/**/*.md)` to scope hooks to content files only.
- **Hook type**: `"prompt"` — sends a natural-language prompt to the LLM for evaluation. This aligns with the spec's "pure markdown, no scripts" constraint. The LLM reads the written file and evaluates it against quality rules.

Configuration structure in `.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "prompt",
            "if": "Write(specs/002-linkedin-content-system/content/**/*.md) || Edit(specs/002-linkedin-content-system/content/**/*.md)",
            "prompt": "Read the file that was just written. Verify: (1) word count 150-300 for post drafts, (2) no forbidden phrases, (3) at least one repo fact, (4) at least one business outcome. Report pass/fail with specific issues."
          }
        ]
      }
    ]
  }
}
```

### Alternatives Considered

1. **`type: "command"` with a shell script**: Rejected because the spec explicitly requires pure markdown prompts with no shell scripts. A command-type hook would require a bash or Node.js script to perform validation.

2. **`FileChanged` event**: Fires when any file changes on disk but provides no decision control (cannot block/request fixes). It's a side-effect-only event — unsuitable for guardrails that must flag issues.

3. **`PreToolUse` instead of `PostToolUse`**: Would fire before the file is written, meaning the content doesn't exist yet to validate. `PostToolUse` is correct because it fires after the file exists and can be read back for verification.

4. **Single combined hook**: Rejected in favor of two separate prompt hooks (claim-check and style-check) to maintain single-responsibility and make failure reports clear about which domain flagged the issue.

---

## Research Task 2: Claude Code Command File Structure and Best Practices

**Context**: The content system is implemented as 5 Claude Code commands. Need to confirm command file structure, argument passing, and prerequisite enforcement patterns.

### Decision: Standard `.claude/commands/*.md` files with `$ARGUMENTS` placeholder and inline prerequisite checks

### Rationale

Claude Code commands are markdown files placed in `.claude/commands/`. When a user runs `/command-name arg1 arg2`, Claude Code reads the markdown file and replaces `$ARGUMENTS` with the user's input. The LLM then executes the instructions in the markdown.

Key patterns established from existing commands in this repo (the `speckit.*` family):

1. **Argument access**: Use `$ARGUMENTS` placeholder in the markdown. For `/draft-post 3`, the `$ARGUMENTS` value is `"3"`.
2. **Prerequisite enforcement**: The command prompt includes an explicit prerequisite check section that instructs the LLM to verify required files exist before proceeding. If missing, output an error message naming the missing artifact and the command to produce it, then stop.
3. **File I/O**: Commands use Claude Code's Read and Write tools to read inputs (repo files, prior content artifacts) and write outputs (generated content files).
4. **Overwrite behavior**: Commands write to fixed output paths. Re-running overwrites the previous output. Git history preserves prior versions.

### Alternatives Considered

1. **Claude Code skills (`.claude/skills/*.md`)**: Skills are invoked differently and are typically used for reusable capabilities, not user-facing workflows. Commands are the correct abstraction for user-initiated content generation tasks.

2. **Single mega-command that does everything**: Rejected because the spec defines distinct workflows with dependency ordering. Separate commands enforce the correct workflow and allow the maintainer to re-run individual steps.

---

## Research Task 3: Prompt-Type Hook Capabilities and Limitations

**Context**: The quality guardrails use `type: "prompt"` hooks. Need to understand what the LLM can access and how to structure validation prompts effectively.

### Decision: Two separate prompt hooks — one for claim verification, one for style checking

### Rationale

A `type: "prompt"` hook sends a natural-language prompt to Claude for evaluation after the tool completes. The LLM has access to:

- The full conversation context (including what was just written)
- File system tools (Read, Glob, Grep) to read back the written file and reference files like `claims.md`
- The ability to output a structured pass/fail report

Two hooks are needed because the spec defines two distinct validation domains (FR-022 for claims, FR-023 for style) with different reference data:

1. **Claim-check hook**: Reads the written content file, reads `claims.md`, verifies every factual statement traces to a claim entry. Flags ungrounded claims with location and suggested fix.
2. **Style-check hook**: Reads the written content file, checks word count, opening quality, forbidden phrases, business outcome presence, and repo fact presence. Reports pass/fail per criterion.

Prompt hooks run after `PostToolUse` and their output appears in the conversation, allowing the LLM to iterate on fixes if needed.

### Alternatives Considered

1. **Single combined prompt hook**: Would produce a single report mixing claim and style issues. Rejected for clarity — maintainer should see which validation domain flagged each issue.

2. **HTTP webhook to external validator**: Rejected — requires external infrastructure, violates the "pure markdown, no external tools" constraint.

---

## Research Task 4: Content Dependency Chain Implementation

**Context**: FR-028/FR-029 require hard-blocking dependency enforcement. Need to determine how commands check for prerequisite artifacts.

### Decision: Each command prompt begins with a prerequisite check that uses Read/Glob to verify required files exist

### Rationale

The dependency chain from the spec:

```
/series-plan → (no prerequisites)
/proof-pack → (no prerequisites)
/draft-post N → requires series-plan.md AND claims.md
/repurpose-post N → requires posts/post-N/draft-*.md
/comment-bank → requires claims.md
```

Each command's markdown prompt includes a "Prerequisite Check" section at the top that:

1. Attempts to read or glob for the required file(s)
2. If any file is missing, outputs an error: `"ERROR: Missing prerequisite. Run /[command] first to generate [artifact]."`
3. Stops execution — does not proceed to content generation

This is implementable purely in the markdown prompt (no scripts needed). The LLM follows the instruction to check file existence before generating content.

### Alternatives Considered

1. **No dependency enforcement (generate everything inline)**: Rejected per FR-028 — commands must hard-block when prerequisites are missing.

2. **Soft warning instead of hard block**: Rejected per spec clarification — hard-block was explicitly chosen over warnings.

---

## Research Task 5: Repo-Grounded Proof Extraction Strategy

**Context**: FR-005–FR-009 require scanning the repository to extract verifiable factual claims. Need to determine which repo areas yield the strongest content-worthy facts.

### Decision: Scan 7 repository areas in priority order, mapping findings to 6 claim categories

### Rationale

The repository contains these content-worthy areas (ordered by value density):

1. **Apex MCP framework classes** (`force-app/main/mcp/classes/`): 40 classes implementing MCP tools, resources, prompts, server initialization. Yields claims about framework capabilities, design patterns, and developer experience.

2. **Apex JSON-RPC core** (`force-app/main/json-rpc/classes/`): 14 classes implementing JSON-RPC 2.0 in-repo. Yields claims about zero-dependency protocol implementation, strong typing.

3. **TypeScript stdio proxy** (`packages/salesforce-mcp-lib/src/`): 7 modules handling OAuth, MCP bridging, stdio transport. Yields claims about zero npm dependencies, secure authentication, bridge architecture.

4. **Design documentation** (`docs/`): Wire-contract audit, authorization feasibility report. Yields claims about protocol compliance, security model.

5. **Examples** (`examples/`): Minimal and e2e-http-endpoint examples. Yields claims about developer experience, getting-started simplicity.

6. **Package configuration** (`sfdx-project.json`, `packages/salesforce-mcp-lib/package.json`): Version history, namespace decisions. Yields claims about packaging and distribution.

7. **Specs and plans** (`specs/001-apex-mcp-server/`): Architectural decisions, design rationale. Yields claims about deliberate design choices.

The 6 claim categories from FR-007 map to these areas:

| Claim Category | Primary Source Areas |
|---|---|
| Package purpose | Areas 1, 3, 5 |
| Architecture decisions | Areas 1, 2, 4, 7 |
| Developer experience | Areas 5, 1, 6 |
| Security model | Areas 3, 4 |
| Deployment model | Areas 6, 3 |
| Differentiation from alternatives | Areas 1, 2, 3, 7 |

### Alternatives Considered

1. **Scan only source code, ignore docs/specs**: Rejected — design documentation (`wire-contract-audit`, `authorization-feasibility-report`) contains high-value claims about deliberate architectural choices that source code alone doesn't convey.

2. **Include test files as claim sources**: Rejected — test code demonstrates what works but is not quotable content. Test coverage numbers could be extracted if available, but test assertions are too verbose for LinkedIn content.

---

## Research Task 6: LinkedIn Post Formatting Best Practices

**Context**: Posts must be 150–300 words, open with curiosity, avoid generic AI hype, and target Salesforce developers/architects/AI builders.

### Decision: Follow the technical-LinkedIn content formula: contrarian hook → specific problem → repo-grounded solution → business outcome → soft CTA

### Rationale

Effective technical LinkedIn content for developer audiences follows a consistent structure:

1. **Opening hook (2–3 lines)**: Must create a "pattern interrupt" — something the reader doesn't expect. Five framing angles work well for technical content:
   - **Pain-first**: Start with a frustration the audience recognizes
   - **Misconception-first**: Challenge a belief the audience holds
   - **Architecture-first**: Lead with a technical decision that surprises
   - **Business-first**: Lead with a concrete business outcome
   - **Curiosity-first**: Pose a question that demands an answer

2. **Body (short paragraphs, 1–3 sentences each)**: Each paragraph makes one point. At least one paragraph must reference a specific repo artifact (file, class, decision). At least one must state a business outcome.

3. **Forbidden patterns**: "AI is changing everything," "the future of," "game-changer," "revolutionary," "next-generation," excessive emoji, hashtag-stuffing. These trigger audience disengagement.

4. **CTA (final 1–2 lines)**: Soft — invite comment, point to repo link, or ask a question. Hard CTAs ("Buy now!") don't work for developer audiences.

5. **Word count**: LinkedIn's "see more" fold appears at ~210 characters. The full post should be 150–300 words. The opening 2–3 lines (before the fold) are the highest-leverage text.

### Alternatives Considered

1. **Longer-form posts (500+ words)**: LinkedIn's algorithm penalizes very long posts for engagement rate. 150–300 words is the sweet spot for technical content.

2. **Heavy use of formatting (bold, bullets, emojis)**: Some works, but the spec's target audience (Salesforce devs, architects) responds better to substantive content than formatting tricks. Minimal formatting is preferred.
