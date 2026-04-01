---
description: Generate a full long-form technical article from the article plan
---

## User Input

```text
$ARGUMENTS
```

Consider the user input above (if not empty) as additional tone, audience, or focus overrides.

## Purpose

Generate a complete long-form article (1500–2500 words) based on the article plan. The article includes inline code snippets, direct links to repository files, and is grounded in verified claims. Output is a single publish-ready markdown file.

## Prerequisite Check

**Before doing anything else**, verify these required files exist:

1. Read `specs/002-linkedin-content-system/content/article-plan.md`
2. Read `specs/002-linkedin-content-system/content/claims.md`

**If `article-plan.md` is missing**, output the following and STOP — do not proceed:

```
ERROR: Missing prerequisite.
- Article plan not found at specs/002-linkedin-content-system/content/article-plan.md
- Run `/article-plan` first to generate it.
```

**If `claims.md` is missing**, output the following and STOP — do not proceed:

```
ERROR: Missing prerequisite.
- Claims not found at specs/002-linkedin-content-system/content/claims.md
- Run `/proof-pack` first to generate it.
```

## Instructions

### Step 1: Load Context

1. Read `specs/002-linkedin-content-system/content/article-plan.md` — extract:
   - Article title, subtitle, metadata
   - All sections with their key points, target word counts, claims, repo links, and code snippet indicators
2. Read `specs/002-linkedin-content-system/content/claims.md` — load all claims for inline referencing
3. Read the actual source files indicated by "Code snippet" fields in the article plan — extract verbatim code excerpts to embed in the article

### Step 2: Write the Article

Write the full article following the plan's section structure. The article MUST:

- Be **1500–2500 words** total (count carefully)
- Follow the **section order and headings** from the article plan
- Hit each section's **target word count** (±20%)
- Include **every key point** listed in the plan for each section
- Embed **inline code snippets** where the plan indicates — use fenced code blocks with language tags (```apex, ```typescript, ```bash)
- Include **direct GitHub links** to referenced files using the format `[descriptive text](https://github.com/damecek/salesforce-mcp-lib/blob/main/path)`
- Reference **verified claims** — do not invent capabilities or stats not in claims.md
- Use **no forbidden phrases**: "AI is changing everything," "the future of," "game-changer," "revolutionary," "next-generation"
- Maintain a **technical-but-accessible tone** — precise enough for developers, clear enough for technical managers
- Include a **TL;DR** block at the top (3–4 bullet points summarizing the article)

#### Writing style guidelines:

- **Lead with specifics, not abstractions** — "12 lines of Apex" not "minimal boilerplate"
- **Show, don't just tell** — use code snippets as evidence
- **Link generously** — every mentioned file, class, or document should link to its GitHub URL
- **Use subheadings** within long sections for scannability
- **One idea per paragraph** — keep paragraphs to 3–5 sentences max

### Step 3: Generate Hashtags

Generate a hashtag block for the article:

- Always include: `#Salesforce #MCP #OpenSource`
- Add 2–3 topic-specific hashtags
- Total: 5–6 hashtags

### Step 4: Validate

Before writing output, verify:

1. **Word count** is 1500–2500
2. **All plan sections** are present with correct headings
3. **At least 3 code snippets** are embedded (fenced code blocks)
4. **At least 5 GitHub links** are included (to specific files)
5. **No unsourced claims** — every factual statement traces to claims.md
6. **No forbidden phrases** present
7. **TL;DR block** is present at the top

### Step 5: Write Output

Write 2 files:

**File 1**: `specs/002-linkedin-content-system/content/article/draft.md`

```markdown
# [Article Title]

*[Subtitle]*

**Word count**: [N]
**Claims referenced**: [C-XXX, C-YYY, ...]
**Repo**: https://github.com/damecek/salesforce-mcp-lib

---

## TL;DR

- [bullet 1]
- [bullet 2]
- [bullet 3]
- [bullet 4]

---

[Full article text with sections, code snippets, and links]

---

**Hashtags**: [copy-paste line]
```

**File 2**: `specs/002-linkedin-content-system/content/article/hashtags.md`

```markdown
# Hashtags: Article

## Copy-paste block

[single line of 5–6 hashtags]

## Breakdown

- **Fixed (always)**: #Salesforce #MCP #OpenSource
- **Topic-specific**: [2–3 hashtags with brief rationale for each]
```

## Error Handling

| Condition | Response |
|---|---|
| Missing prerequisites | HARD BLOCK — see Prerequisite Check above |
| Article plan has fewer than 6 sections | WARNING: proceed but note deviation |
| Code snippet source file unreadable | Skip snippet, add `<!-- TODO: add code snippet from [file] -->` placeholder |
| Word count outside 1500–2500 after drafting | Adjust: trim verbose sections or expand thin ones before final output |
