# Quickstart: LinkedIn Content System

**Feature**: 002-linkedin-content-system
**Date**: 2026-03-31

## What This Is

A Claude Code command suite for generating a repo-grounded, 5-part LinkedIn series promoting the Salesforce MCP library. All commands run inside Claude Code and produce markdown content files. No external tools, no scripts, no compiled code.

## Prerequisites

- Claude Code CLI installed and configured
- Working directory: `/Users/adam/IdeaProjects/salesforce-mcp-lib/` (or any checkout of the repo)
- The repository must contain the existing Apex and TypeScript source (the content system extracts facts from it)

## Setup

### Step 1: Install Command Files

Place the 5 command files in `.claude/commands/`:

```
.claude/commands/
├── series-plan.md
├── proof-pack.md
├── draft-post.md
├── comment-bank.md
└── repurpose-post.md
```

### Step 2: Configure Quality Hooks

Add the hook configuration to `.claude/settings.json` (create the file if it doesn't exist):

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
            "prompt": "CLAIM CHECK: Read the file that was just written. Then read specs/002-linkedin-content-system/content/claims.md. Identify every factual statement in the written file. For each, verify it matches or is supported by a claim in claims.md. If claims.md does not exist, output a skip warning. Otherwise report pass/fail with details for each ungrounded claim."
          }
        ]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "prompt",
            "if": "Write(specs/002-linkedin-content-system/content/posts/**/draft-*.md) || Edit(specs/002-linkedin-content-system/content/posts/**/draft-*.md)",
            "prompt": "STYLE CHECK: Read the post draft just written. Check: (1) word count 150-300, (2) opening creates curiosity without clickbait, (3) no forbidden phrases, (4) business outcome present, (5) repo fact present. Report pass/fail per criterion with specific issues and fixes."
          }
        ]
      }
    ]
  }
}
```

## Usage Workflow

Commands must be run in dependency order. The system hard-blocks if prerequisites are missing.

### Phase 1: Foundation (no dependencies)

```
/series-plan
```
Generates `content/series-plan.md` — the 5-topic editorial roadmap.

```
/proof-pack
```
Generates `content/claims.md` — 15+ repo-grounded factual claims.

These two commands can be run in any order. Both must complete before drafting posts.

### Phase 2: Drafting (requires series-plan + claims)

```
/draft-post 1
/draft-post 2
/draft-post 3
/draft-post 4
/draft-post 5
```

Each generates 4 files in `content/posts/post-N/`:
- `draft-technical.md` — Architecture-focused variant
- `draft-business.md` — Problem-solution variant
- `draft-founder.md` — Story-driven variant
- `hooks.md` — 5 opening hook variants

Quality hooks auto-trigger after each write:
- **Claim check**: Verifies factual statements against `claims.md`
- **Style check**: Verifies word count, opening quality, forbidden phrases, outcomes, facts

### Phase 3: Supporting Content

```
/comment-bank
```
Generates `content/comment-bank.md` — 20+ pre-written replies. Requires `claims.md`.

```
/repurpose-post 1
/repurpose-post 2
...
```
Generates `content/posts/post-N/derivatives.md` — 4 derivative formats. Requires corresponding drafts.

## Dependency Chain

```
/series-plan ──────────┐
                       ├──→ /draft-post N ──→ /repurpose-post N
/proof-pack ───────────┤
                       └──→ /comment-bank
```

## Re-Running Commands

All commands overwrite their output files in place. Git history preserves prior versions. There is no in-system versioning.

## Content Output Directory

All generated content lives under:
```
specs/002-linkedin-content-system/content/
├── series-plan.md
├── claims.md
├── comment-bank.md
└── posts/
    ├── post-1/
    │   ├── draft-technical.md
    │   ├── draft-business.md
    │   ├── draft-founder.md
    │   ├── hooks.md
    │   └── derivatives.md
    ├── post-2/ ... post-5/
```

Total: up to 27 generated content files.

## Troubleshooting

| Problem | Solution |
|---|---|
| `/draft-post` says "Missing prerequisite" | Run `/series-plan` and `/proof-pack` first |
| `/repurpose-post 3` says "No drafts found" | Run `/draft-post 3` first |
| Quality hook reports ungrounded claim | Either add the claim via `/proof-pack` or rephrase the text to match an existing claim |
| Style check fails on word count | Trim or expand the post body to 150–300 words |
| Hook doesn't trigger after writing | Verify `.claude/settings.json` hook config is correct and file path matches the `if` pattern |
| Commands not appearing in Claude Code | Ensure files are in `.claude/commands/` with `.md` extension |

## Verification Checklist

After setup, verify the system works:

1. [ ] Run `/series-plan` — should produce `content/series-plan.md` with 5 topics
2. [ ] Run `/proof-pack` — should produce `content/claims.md` with 15+ claims
3. [ ] Run `/draft-post 1` — should produce 3 drafts + hooks, quality hooks should fire
4. [ ] Try `/draft-post 1` without claims.md — should hard-block with error
5. [ ] Run `/comment-bank` — should produce 20+ replies
6. [ ] Run `/repurpose-post 1` — should produce 4 derivative formats
