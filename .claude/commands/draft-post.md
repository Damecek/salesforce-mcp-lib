---
description: Generate 3 style variants and 5 opening hooks for a specific LinkedIn series post
---

## User Input

```text
$ARGUMENTS
```

## Purpose

Generate 3 style variants (technical, business, founder) and 5 opening hooks for a specified post number (1–5) in the LinkedIn series.

## Prerequisite Check

**Before doing anything else**, verify these required files exist:

1. Read `specs/002-linkedin-content-system/content/series-plan.md`
2. Read `specs/002-linkedin-content-system/content/claims.md`

**If `series-plan.md` is missing**, output the following and STOP — do not proceed:

```
ERROR: Missing prerequisite.
- Series plan not found at specs/002-linkedin-content-system/content/series-plan.md
- Run `/series-plan` first to generate it.
```

**If `claims.md` is missing**, output the following and STOP — do not proceed:

```
ERROR: Missing prerequisite.
- Claims not found at specs/002-linkedin-content-system/content/claims.md
- Run `/proof-pack` first to generate it.
```

## Argument Parsing

Parse the post number from `$ARGUMENTS`:

- Must be an integer from 1 to 5
- **If no argument provided**: Output `"ERROR: Post number required. Usage: /draft-post N where N is 1–5."` and STOP.
- **If argument is not 1–5**: Output `"ERROR: Invalid post number '$ARGUMENTS'. Must be 1–5."` and STOP.

## Instructions

### Step 1: Load Context

1. Read `specs/002-linkedin-content-system/content/series-plan.md` — extract Topic N's structure:
   - Title, core message, CTA angle, contrarian hook, repo artifact references
2. Read `specs/002-linkedin-content-system/content/claims.md` — identify claims that support Topic N:
   - Map at least 2 supporting claims to this topic
   - If fewer than 2 claims support the topic, output a WARNING but proceed with available claims

### Step 2: Generate 3 Post Variants

Generate 3 distinct style variants for the post. Each variant MUST:

- Be **150–300 words** (count carefully)
- Include at least **1 specific repo fact** (referencing a real file, class, or design decision from the repository)
- Include at least **1 business outcome** (a concrete benefit stated in business terms)
- Open with a **strong first line** that creates curiosity and clarity
- Close with a **soft CTA** aligned with the topic's CTA angle
- Contain **NO forbidden phrases**: "AI is changing everything," "the future of," "game-changer," "revolutionary," "next-generation"
- Reference at least 1 claim from `claims.md` for factual accuracy

#### Variant styles:

1. **Technical** (`draft-technical.md`): Architecture-focused. Leads with how the system works. Uses precise technical language. Appeals to developers and architects who want to understand the design.

2. **Business** (`draft-business.md`): Problem-solution, outcome-focused. Leads with the business problem this solves. Uses business language with just enough technical detail to be credible. Appeals to engineering managers and decision-makers.

3. **Founder** (`draft-founder.md`): Story-driven, community-focused. Leads with the journey or motivation behind the project. Uses authentic, personal voice. Appeals to open-source enthusiasts and developer community members.

### Step 3: Generate 5 Opening Hooks

Generate exactly 5 opening hook variants for this topic. Each hook:

- Is **2–3 lines** long
- Is **technically accurate** — no invented capabilities or false claims
- Contains **no generic superlatives or hype language**
- Provides a distinct framing angle

#### Hook framings (one of each):

1. **Pain-first**: Start with a frustration the audience recognizes
2. **Misconception-first**: Challenge a belief the audience holds
3. **Architecture-first**: Lead with a technical decision that surprises
4. **Business-first**: Lead with a concrete business outcome
5. **Curiosity-first**: Pose a question that demands an answer

### Step 4: Write Output Files

Write 4 files for the specified post number N:

**File 1**: `specs/002-linkedin-content-system/content/posts/post-N/draft-technical.md`

```markdown
# Post N — Technical: [Topic Title]

**Topic**: [N] — [Title]
**Variant**: Technical
**Word count**: [N]
**Claims referenced**: [C-XXX, C-YYY]

---

[Full post text]
```

**File 2**: `specs/002-linkedin-content-system/content/posts/post-N/draft-business.md`

```markdown
# Post N — Business: [Topic Title]

**Topic**: [N] — [Title]
**Variant**: Business
**Word count**: [N]
**Claims referenced**: [C-XXX, C-YYY]

---

[Full post text]
```

**File 3**: `specs/002-linkedin-content-system/content/posts/post-N/draft-founder.md`

```markdown
# Post N — Founder: [Topic Title]

**Topic**: [N] — [Title]
**Variant**: Founder
**Word count**: [N]
**Claims referenced**: [C-XXX, C-YYY]

---

[Full post text]
```

**File 4**: `specs/002-linkedin-content-system/content/posts/post-N/hooks.md`

```markdown
# Hooks: Post N — [Topic Title]

**Topic**: [N] — [Title]

## 1. Pain-First

[2–3 lines]

## 2. Misconception-First

[2–3 lines]

## 3. Architecture-First

[2–3 lines]

## 4. Business-First

[2–3 lines]

## 5. Curiosity-First

[2–3 lines]
```

Replace `N` with the actual post number in all file paths and content.

## Error Handling

| Condition | Response |
|---|---|
| Missing prerequisites | HARD BLOCK — see Prerequisite Check above |
| Post number not 1–5 | ERROR with usage instructions |
| No `$ARGUMENTS` provided | ERROR with usage instructions |
| Topic has fewer than 2 supporting claims | WARNING: "Topic [N] has only [X] supporting claims. Consider running `/proof-pack` again to expand coverage." Proceed with available claims. |
