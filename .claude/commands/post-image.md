---
description: Generate an infographic image prompt for a LinkedIn post using Gemini via nanobanana MCP
---

## User Input

```text
$ARGUMENTS
```

## Purpose

Read a completed LinkedIn post draft and generate a detailed image generation prompt optimized for Gemini (via nanobanana MCP). The output is a ready-to-use prompt file and — if the nanobanana MCP tool or `seo-image-gen` skill is available — the generated image itself.

## Argument Parsing

Parse the post number from `$ARGUMENTS`:

- Must be an integer (e.g., 1, 2, 3, ..., N)
- **If no argument provided**: Output `"ERROR: Post number required. Usage: /post-image N"` and STOP.
- **If argument is not a valid number**: Output `"ERROR: Invalid post number '$ARGUMENTS'."` and STOP.

## Prerequisite Check

**Before doing anything else**, verify draft files exist for the specified post number N.

Check for at least one draft file at `specs/002-linkedin-content-system/content/posts/post-N/draft-*.md`.

**If no draft files exist for post N**, output the following and STOP:

```
ERROR: Missing prerequisite.
- No drafts found for post [N] at specs/002-linkedin-content-system/content/posts/post-N/
- Run `/draft-post [N]` first to generate them.
```

## Instructions

### Step 1: Load Post Context

1. Read all available draft variants for post N (in preference order):
   - `draft-technical.md` (preferred — most concept-rich for visual representation)
   - `draft-business.md`
   - `draft-founder.md`
2. Read `specs/002-linkedin-content-system/content/posts/post-N/hooks.md` if it exists — hooks often contain the most visually evocative framings.
3. Extract from the drafts:
   - **Core message** (1 sentence)
   - **Key visual concepts** — technical terms, metaphors, or contrasts that can be visualized (e.g., "two interfaces," "page layout vs. MCP tool," "human → agent")
   - **Target audience** — infer from draft variant (developer, business, community)

### Step 2: Design the Visual Concept

Choose ONE infographic concept from this priority list. Pick the first one that fits the post's core message:

1. **Before/After Split** — when the post contrasts an old approach vs. a new one (e.g., "human interface" vs. "AI agent interface")
2. **Architecture Diagram** — when the post explains how components connect (e.g., Salesforce org → MCP server → AI agent)
3. **Mapping/Translation** — when the post draws parallels between two systems (e.g., page layout ↔ SOQL tool, screen flow ↔ subflow tool)
4. **Layered Stack** — when the post describes layers of a system (e.g., security layers, protocol layers)
5. **Flow/Sequence** — when the post describes a process from start to end (e.g., request flow from agent to Salesforce)
6. **Stats/Metrics Highlight** — when the post has specific numbers (e.g., "77 classes, 0 dependencies, 12 lines")

### Step 3: Generate the Image Prompt

Generate a detailed prompt for Gemini image generation. The prompt MUST include:

#### Required elements:

1. **Format specification**: `LinkedIn infographic, 1200x627px landscape format, high resolution`
2. **Style direction**: Clean, modern, professional. Dark background (dark navy or charcoal) with accent colors (Salesforce blue #0176D3 as primary, white text, subtle gradients). No stock-photo look. Technical but accessible.
3. **Layout description**: Precise description of what goes where — left side, right side, center, headers, labels.
4. **Content elements**: Exact text labels, icons, or symbols to include. Keep text minimal — max 6–8 short labels.
5. **Visual metaphor**: The core concept translated into a visual (e.g., "two doors into the same building — one labeled 'Page Layout' for humans, one labeled 'MCP Tool' for AI agents")
6. **Exclusions**: No photos of people, no generic tech imagery, no clipart. No Salesforce logo (trademark). No code screenshots.

#### Prompt structure template:

```
Create a LinkedIn infographic (1200x627px, landscape).

**Visual concept**: [1-2 sentences describing the core visual metaphor]

**Layout**:
- [Left/Top section]: [what goes here]
- [Center]: [what goes here]
- [Right/Bottom section]: [what goes here]

**Style**: [color palette, typography direction, mood]

**Text labels** (exact text to include):
- [Label 1]
- [Label 2]
- ...

**Do NOT include**: [exclusions]
```

### Step 4: Write Output

Write the prompt to:

```
specs/002-linkedin-content-system/content/posts/post-N/image-prompt.md
```

Use this format:

```markdown
# Image Prompt: Post N — [Topic Title]

**Post**: N
**Source variant**: [technical/business/founder]
**Visual concept**: [chosen concept type from Step 2]
**Generated**: [date]

## Core Message (for visual)

[1 sentence — the single idea the image must communicate]

## Gemini Prompt

[Full prompt text, ready to copy-paste into nanobanana / Gemini]

## Alt Text (for LinkedIn)

[1-2 sentence accessible description of what the generated image shows — for the LinkedIn alt-text field]

## Usage Notes

- **LinkedIn image specs**: 1200x627px recommended for feed posts
- **Fallback**: If generation fails, use the alt text as a text-only post header
- **Regeneration**: Adjust the prompt and re-run if the visual doesn't match the post's tone
```

### Step 5: Output

After writing the prompt file, output:

```
✅ Image prompt written to specs/002-linkedin-content-system/content/posts/post-N/image-prompt.md
Copy the "Gemini Prompt" section into Gemini / nanobanana to generate the infographic.
```

## Error Handling

| Condition | Response |
|---|---|
| Missing prerequisites | HARD BLOCK — see Prerequisite Check above |
| Post number invalid | ERROR with usage instructions |
| No `$ARGUMENTS` provided | ERROR with usage instructions |
| Image generation tool unavailable | Write prompt file, output INFO message with manual instructions |
| Image generation fails | Keep prompt file, output WARNING with the error, suggest manual generation |
