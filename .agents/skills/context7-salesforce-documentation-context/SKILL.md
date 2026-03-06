---
name: context7-salesforce-documentation-context
description: Use Context7 to verify and retrieve up-to-date information from the `damecek/salesforce-documentation-context` documentation via the fixed `libraryId:/damecek/salesforce-documentation-context`. Use in any Salesforce project when you need to confirm uncertain details, fetch newer information than the model may know, or get accurate examples/usage guidance from that documentation set; always call `mcp__context7__query-docs` directly and skip `mcp__context7__resolve-library-id`.
---

# Context7 Salesforce Documentation Context

## Quick Start

- Prerequisite: the Context7 MCP server is configured and available.
- Fixed library id: `"/damecek/salesforce-documentation-context"`.
- Hard rule: call `mcp__context7__query-docs` directly; do not call `mcp__context7__resolve-library-id`.

Example tool call:

```json
{
  "libraryId": "/damecek/salesforce-documentation-context",
  "query": "How do I <do X> in a Salesforce project? Provide steps and a minimal code example."
}
```

## Workflow

1. Form a precise query.
   - Include the exact symbol names and file paths if known (classes, methods, CLI commands, config keys).
   - Specify the desired output: “steps”, “code example”, “edge cases”, “gotchas”, “latest behavior”.
   - Ask for citations/snippets when you need to justify a claim.
2. Call `mcp__context7__query-docs` with:
   - `libraryId: "/damecek/salesforce-documentation-context"`
   - `query: "<your question>"`
3. Use the returned information to update your answer or implementation.
   - If results conflict with assumptions, prefer Context7 results over memory.
   - If results are incomplete, iterate with a narrower follow-up query.

## Query Patterns

- Verify a claim:
  - `query`: "Verify whether <claim>. If false, provide the correct behavior and where it is documented."
- Ask for examples:
  - `query`: "Show a minimal, correct example for <task>. Include any required setup/config."
 - Map docs to your current project:
  - `query`: "Given my context (<brief project details>), which documented approach applies and what are the key steps?"

## Failure Modes And Fallbacks

- If the Context7 MCP server/tool is unavailable, fall back to the local project inspection (search/read code/config) and explicitly state what you could not verify from the docs library.
