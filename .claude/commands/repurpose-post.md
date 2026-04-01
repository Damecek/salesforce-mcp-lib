---
description: Transform a completed post draft into 4 derivative formats for multi-channel distribution
---

## User Input

```text
$ARGUMENTS
```

## Purpose

Transform a completed LinkedIn post draft into 4 derivative formats: short post, carousel script, comment version, and DM explanation.

## Prerequisite Check

**Before doing anything else**, verify draft files exist for the specified post number.

Parse the post number from `$ARGUMENTS`:

- Must be an integer from 1 to 5
- **If no argument provided**: Output `"ERROR: Post number required. Usage: /repurpose-post N where N is 1–5."` and STOP.
- **If argument is not 1–5**: Output `"ERROR: Invalid post number '$ARGUMENTS'. Must be 1–5."` and STOP.

Check for draft files at `specs/002-linkedin-content-system/content/posts/post-N/draft-*.md`.

**If no draft files exist for post N**, output the following and STOP:

```
ERROR: Missing prerequisite.
- No drafts found for post [N] at specs/002-linkedin-content-system/content/posts/post-N/
- Run `/draft-post [N]` first to generate them.
```

## Instructions

### Step 1: Load Source Draft

1. Read all available draft variants for post N:
   - `draft-technical.md`
   - `draft-business.md`
   - `draft-founder.md`
2. Select the best variant as the source for repurposing. Preference order:
   - If multiple variants exist, use the **business** variant (most accessible for derivative formats)
   - If only one exists, use that one
3. Note the source variant and its core message + key repo fact for preservation validation.

### Step 2: Generate 4 Derivative Formats

Generate all 4 derivatives from the selected source draft:

#### 1. Short Post (under 100 words)

Condense the full post into a punchy version under 100 words. MUST preserve:
- The **core message** from the original
- At least **1 key repo fact** from the original

#### 2. Carousel Script (5–8 slides)

Create a carousel-style script with 5–8 slides. Each slide has:
- **Headline**: Bold, attention-grabbing (5–10 words)
- **Body**: Supporting text (1–3 sentences)

The carousel should tell a complete story from slide 1 to the final slide. The last slide should include a CTA. MUST preserve:
- The **core message**
- At least **1 key repo fact**

#### 3. Comment Version (2–3 sentences)

Create a standalone comment that could be posted under someone else's related LinkedIn post. Must:
- Be **2–3 sentences** only
- Be self-contained and conversational
- Reference the project naturally without being promotional
- Preserve the **core message** in condensed form

#### 4. DM Explanation (3–5 sentences)

Create an informal, direct-message-style explanation. Must:
- Be **3–5 sentences**
- Use **informal, conversational tone** (as if explaining to a colleague over chat)
- Preserve the **core message** and at least **1 repo fact**
- Not sound like marketing copy

### Step 3: Validate

Before writing output, verify:

1. **Short post** is under 100 words
2. **Carousel** has 5–8 slides, each with headline + body
3. **Comment version** is 2–3 sentences
4. **DM explanation** is 3–5 sentences
5. **Core message preserved** in all 4 derivatives
6. **Key repo fact preserved** in short post, carousel, and DM explanation

### Step 4: Write Output

Write derivatives to:

```
specs/002-linkedin-content-system/content/posts/post-N/derivatives.md
```

Use this format:

```markdown
# Derivatives: Post N — [Topic Title]

**Source variant**: [technical/business/founder]
**Generated**: [date]

## Short Post

**Word count**: [N] (max: 100)

[Short post text]

## Carousel Script

**Slides**: [N] (target: 5–8)

### Slide 1: [Headline]
[Body text]

### Slide 2: [Headline]
[Body text]

### Slide 3: [Headline]
[Body text]

...

### Slide [N]: [Headline — CTA]
[Body text with call-to-action]

## Comment Version

**Sentences**: [N] (target: 2–3)

[Comment text]

## DM Explanation

**Sentences**: [N] (target: 3–5)

[DM text]

---

## Validation

- Short post word count: [N] (max: 100)
- Carousel slides: [N] (target: 5–8)
- Comment sentences: [N] (target: 2–3)
- DM sentences: [N] (target: 3–5)
- Core message preserved: [YES/NO]
- Key repo fact preserved: [YES/NO]
```

Replace `N` with the actual post number in all file paths and content.

## Error Handling

| Condition | Response |
|---|---|
| Missing prerequisites | HARD BLOCK — see Prerequisite Check above |
| Post number not 1–5 | ERROR with usage instructions |
| No `$ARGUMENTS` provided | ERROR with usage instructions |
