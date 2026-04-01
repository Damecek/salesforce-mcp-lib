---
description: Generate 20+ pre-written comment replies organized by question category
---

## User Input

```text
$ARGUMENTS
```

Consider the user input above (if not empty) as additional question categories or focus areas.

## Purpose

Generate 20+ pre-written comment replies covering predictable questions and objections about the Salesforce MCP library. Replies are organized by question category and grounded in repository facts.

## Prerequisite Check

**Before doing anything else**, verify this required file exists:

1. Read `specs/002-linkedin-content-system/content/claims.md`

**If `claims.md` is missing**, output the following and STOP — do not proceed:

```
ERROR: Missing prerequisite.
- Claims not found at specs/002-linkedin-content-system/content/claims.md
- Run `/proof-pack` first to generate it.
```

## Instructions

### Step 1: Load Claims

Read `specs/002-linkedin-content-system/content/claims.md` to ground all replies in verified repository facts.

### Step 2: Generate Replies by Category

Generate reply variants for at least these 6 mandatory categories:

#### Category 1: "What is MCP?"
Generate at least 3 reply variants explaining the Model Context Protocol and how this library implements it. Ground explanations in claims about the project's architecture and purpose.

#### Category 2: "Why not Agentforce?"
Generate at least 3 reply variants differentiating this approach from Salesforce's Agentforce. Cite specific architectural differences and capability claims.

#### Category 3: "Why Apex?"
Generate at least 3 reply variants explaining the choice of Apex as the server-side language. Reference claims about Salesforce platform constraints, performance, and developer familiarity.

#### Category 4: "Why local bridge?"
Generate at least 3 reply variants explaining the TypeScript stdio proxy architecture. Reference claims about the bridge design, security model, and deployment simplicity.

#### Category 5: "How is auth handled?"
Generate at least 3 reply variants explaining the authentication and authorization model. Reference claims about OAuth handling, credential management, and security design.

#### Category 6: "Can this be used in enterprise?"
Generate at least 3 reply variants addressing enterprise readiness. Reference claims about packaging, deployment, security, and scalability.

### Reply Quality Rules

Each reply MUST:

- Be **2–5 sentences** long
- Be **technically accurate** — all factual statements must trace to claims
- **Cite a repo fact** for technical questions (reference a specific file, class, or design decision)
- Sound **conversational and helpful**, not defensive or salesy
- Be **self-contained** — readable without additional context

### Step 3: Validate

Before writing output, verify:

1. **At least 20 total replies** across all categories
2. **At least 6 categories** present (the 6 mandatory ones above + any user-requested additions)
3. **At least 3 replies per category**
4. **Every reply is 2–5 sentences**
5. **Technical questions include repo fact citations**

### Step 4: Write Output

Write the comment bank to:

```
specs/002-linkedin-content-system/content/comment-bank.md
```

Use this format:

```markdown
# Comment Bank: Salesforce MCP Library

**Generated**: [date]
**Total replies**: [N]
**Categories**: [N]

## "What is MCP?"

### Reply 1
[2–5 sentences]

### Reply 2
[2–5 sentences]

### Reply 3
[2–5 sentences]

## "Why not Agentforce?"

### Reply 1
[2–5 sentences]

...

## "Why Apex?"

...

## "Why local bridge?"

...

## "How is auth handled?"

...

## "Can this be used in enterprise?"

...

---

## Validation

- Total replies: [N] (minimum: 20)
- Categories: [N] (minimum: 6)
- Replies per category: [min N, max N]
- All technical replies cite repo facts: [YES/NO]
```

## Error Handling

| Condition | Response |
|---|---|
| Missing prerequisite | HARD BLOCK — see Prerequisite Check above |
| Fewer than 20 replies generated | WARNING in output, but proceed |
