# Hook Contracts: LinkedIn Content System

**Feature**: 002-linkedin-content-system
**Date**: 2026-03-31

## Overview

The content system uses 2 prompt-type hooks configured in `.claude/settings.json` under the `PostToolUse` event. Both hooks trigger automatically when a content file under `specs/002-linkedin-content-system/content/` is written or edited. They perform LLM-based validation and report pass/fail results inline in the conversation.

## Hook Configuration Location

All hooks are configured in `.claude/settings.json` at the project root:

```json
{
  "hooks": {
    "PostToolUse": [
      // Hook 1: Claim Check
      // Hook 2: Style Check
    ]
  }
}
```

---

## Hook 1: Claim Check

**Event**: `PostToolUse`
**Matcher**: `Write|Edit`
**Filter**: Content files under `specs/002-linkedin-content-system/content/posts/` and `specs/002-linkedin-content-system/content/comment-bank.md`
**Type**: `prompt`

### Purpose

Verify that every factual statement in the written content traces back to an entry in `claims.md` (FR-022). Flag ungrounded claims with their location in the text and a suggested fix (FR-024).

### Trigger Conditions

Fires when any of these paths are written or edited:
- `specs/002-linkedin-content-system/content/posts/post-*/draft-*.md`
- `specs/002-linkedin-content-system/content/posts/post-*/hooks.md`
- `specs/002-linkedin-content-system/content/comment-bank.md`

Does NOT fire for:
- `specs/002-linkedin-content-system/content/series-plan.md` (no factual claims to verify)
- `specs/002-linkedin-content-system/content/posts/post-*/derivatives.md` (derived from already-verified drafts)

### Validation Logic (Prompt)

The prompt instructs the LLM to:

1. Read the file that was just written.
2. Read `specs/002-linkedin-content-system/content/claims.md`.
3. Identify every factual statement in the written file (technical claims, statistics, capability descriptions, architectural assertions).
4. For each factual statement, check if it matches or is supported by a claim in `claims.md`.
5. Report results:

**Pass**:
```
✅ Claim Check PASSED — all [N] factual statements verified against claims.md
```

**Fail**:
```
❌ Claim Check FAILED — [N] ungrounded claims found:

1. Line [X]: "[quoted text]"
   Issue: No matching claim in claims.md
   Suggested fix: [Add claim via /proof-pack or rephrase to match claim C-XXX]

2. Line [Y]: "[quoted text]"
   ...
```

### Error Handling

| Condition | Behavior |
|---|---|
| `claims.md` does not exist | Skip validation. Output: "⚠️ Claim check skipped — claims.md not found. Run `/proof-pack` first." |
| Written file is empty | Skip validation silently. |
| Written file is not a content file (path doesn't match) | Hook does not trigger (filtered by `if` condition). |

---

## Hook 2: Style Check

**Event**: `PostToolUse`
**Matcher**: `Write|Edit`
**Filter**: Post draft files under `specs/002-linkedin-content-system/content/posts/`
**Type**: `prompt`

### Purpose

Verify that every post draft meets baseline quality standards: word count, opening quality, absence of forbidden phrases, presence of business outcomes and repo facts (FR-023). Report pass/fail per criterion with specific issues and suggested fixes (FR-024).

### Trigger Conditions

Fires when any of these paths are written or edited:
- `specs/002-linkedin-content-system/content/posts/post-*/draft-*.md`

Does NOT fire for:
- Non-draft content files (series-plan, claims, hooks, derivatives, comment-bank)
- These files have different structural requirements and are not LinkedIn posts

### Validation Logic (Prompt)

The prompt instructs the LLM to:

1. Read the file that was just written.
2. Extract the post body text (excluding metadata headings).
3. Run 5 checks:

| Check | Rule | Reference |
|---|---|---|
| Word count | Body text is 150–300 words | FR-012 |
| Opening quality | First 3 lines create curiosity and clarity without clickbait | FR-013 |
| Forbidden phrases | None of: "AI is changing everything," "the future of," "game-changer," "revolutionary," "next-generation" | FR-014 |
| Business outcome | At least 1 business outcome stated | FR-011 |
| Repo fact | At least 1 specific repository fact cited | FR-011 |

4. Report results:

**Pass**:
```
✅ Style Check PASSED — all 5 criteria met
  - Word count: [N] words (target: 150–300)
  - Opening: Clear and engaging
  - Forbidden phrases: None found
  - Business outcome: Present
  - Repo fact: Present
```

**Fail**:
```
❌ Style Check FAILED — [N]/5 criteria failed:

1. ❌ Word count: [N] words (target: 150–300)
   Suggested fix: [Trim/expand by approximately X words]

2. ❌ Forbidden phrase found: "[phrase]" at line [X]
   Suggested fix: Replace with [specific alternative]

3. ✅ Opening: Clear and engaging
4. ✅ Business outcome: Present
5. ❌ Repo fact: Missing
   Suggested fix: Add a reference to a specific file, class, or design decision from the repository
```

### Error Handling

| Condition | Behavior |
|---|---|
| Written file is empty | Skip validation silently. |
| Written file has no extractable body text | Output: "⚠️ Style check skipped — no post body found in file." |
| File path doesn't match draft pattern | Hook does not trigger. |

---

## Settings.json Configuration

The complete hook configuration to be added to `.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "prompt",
            "if": "Write(specs/002-linkedin-content-system/content/posts/**/draft-*.md) || Write(specs/002-linkedin-content-system/content/posts/**/hooks.md) || Write(specs/002-linkedin-content-system/content/comment-bank.md) || Edit(specs/002-linkedin-content-system/content/posts/**/draft-*.md) || Edit(specs/002-linkedin-content-system/content/posts/**/hooks.md) || Edit(specs/002-linkedin-content-system/content/comment-bank.md)",
            "prompt": "CLAIM CHECK: Read the file that was just written. Then read specs/002-linkedin-content-system/content/claims.md. Identify every factual statement (technical claims, capability descriptions, architectural assertions) in the written file. For each, verify it matches or is supported by a claim in claims.md. If claims.md does not exist, output '⚠️ Claim check skipped — claims.md not found. Run /proof-pack first.' Otherwise report: for PASS output '✅ Claim Check PASSED — all N factual statements verified.' For FAIL output '❌ Claim Check FAILED' followed by each ungrounded claim with its line number, quoted text, and a suggested fix (add via /proof-pack or rephrase to match existing claim)."
          }
        ]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "prompt",
            "if": "Write(specs/002-linkedin-content-system/content/posts/**/draft-*.md) || Edit(specs/002-linkedin-content-system/content/posts/**/draft-*.md)",
            "prompt": "STYLE CHECK: Read the post draft that was just written. Extract the post body text (exclude metadata headings). Check 5 criteria: (1) Word count is 150-300 words, (2) First 3 lines create curiosity and clarity without clickbait, (3) No forbidden phrases ('AI is changing everything', 'the future of', 'game-changer', 'revolutionary', 'next-generation'), (4) At least 1 business outcome stated, (5) At least 1 specific repo fact cited. Report pass/fail for each criterion. For failures include the specific text that triggered it and a suggested fix. Format: '✅ Style Check PASSED' if all pass, or '❌ Style Check FAILED — N/5 criteria failed' with details for each."
          }
        ]
      }
    ]
  }
}
```
