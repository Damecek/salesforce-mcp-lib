<!--
  === Sync Impact Report ===
  Version change: (new) -> 1.0.0
  Modified principles: N/A (initial adoption)
  Added sections:
    - Core Principles (4 principles: AI-Agent-First Development, Agent-Consumable APIs,
      Maintainability & Reusability, Strong Typing)
    - Technology Stack & Constraints
    - Development Workflow
    - Governance
  Removed sections: None
  Templates requiring updates:
    - .specify/templates/plan-template.md       -- no update needed (Constitution Check is dynamic)
    - .specify/templates/spec-template.md       -- no update needed (generic, principle-agnostic)
    - .specify/templates/tasks-template.md      -- no update needed (generic, testing opt-in per spec)
    - .specify/templates/checklist-template.md  -- no update needed (dynamically generated)
    - .specify/templates/agent-file-template.md -- no update needed (generic)
  Follow-up TODOs: None
-->
# Salesforce MCP Library Constitution

## Core Principles

### I. AI-Agent-First Development

All code, documentation, and project structure MUST be optimized for AI agent
comprehension and modification as the primary development workflow.

- File and directory naming MUST be descriptive and follow consistent conventions
  so agents can locate and reason about modules without external guidance.
- Public interfaces MUST include documentation comments that describe purpose,
  parameters, return values, and side effects. Agents rely on inline context to
  make correct decisions.
- Code MUST favor explicit, linear control flow over clever abstractions. Agents
  produce higher-quality output when intent is unambiguous.
- Commit history MUST contain meaningful messages that explain *why* a change was
  made, not just *what* changed. Agents use commit history for context
  reconstruction.

**Rationale**: The project's development lifecycle is driven by AI agents. Every
structural and stylistic decision MUST reduce agent error rates and increase
autonomous task completion.

### II. Agent-Consumable APIs

The library's primary consumers are AI agents connecting to Salesforce over the
MCP protocol. All public interfaces MUST be designed for machine consumption
first.

- Protocol messages MUST conform strictly to JSON-RPC 2.0 and MCP 2025-11-25
  specifications. Deviations break agent interoperability.
- Error responses MUST use structured, typed error codes and messages that agents
  can parse and act on programmatically. Human-readable descriptions are
  supplementary.
- Tool, resource, and prompt definitions MUST include complete, accurate JSON
  Schema descriptors so agents can discover and invoke capabilities without human
  guidance.
- The stdio bridge MUST implement standards-compliant message framing
  (content-length header or newline-delimited) so any conforming MCP client can
  connect without adaptation.

**Rationale**: AI agents cannot ask clarifying questions at runtime. APIs that
are ambiguous, under-documented, or non-conformant cause silent failures in
agent workflows.

### III. Maintainability & Reusability

Every module MUST be self-contained, independently testable, and reusable across
contexts.

- The Apex library MUST remain a standalone 2GP package installable in any
  Salesforce org without modification. No assumptions about the consuming org's
  schema or configuration.
- The Node.js bridge MUST maintain zero production dependencies. All
  functionality MUST rely on Node.js built-in modules only.
- Modules MUST have single, clear responsibilities. If a class or file serves
  multiple unrelated purposes, it MUST be split.
- Shared types and DTOs MUST be defined in dedicated locations (not inline) so
  they can be referenced across modules without circular dependencies.
- Code MUST favor clarity over brevity. Explicit variable names, guard clauses,
  and early returns over nested conditionals.

**Rationale**: A library consumed by external projects and agents cannot afford
hidden coupling, implicit dependencies, or installation friction. Reusability is
only real when the consumer can adopt the library without reading the source.

### IV. Strong Typing

All public APIs, data transfer objects, parameters, and return types MUST use
explicit, concrete types.

- Apex classes extending `JsonRpcParamsBase` MUST define typed properties for
  every expected parameter. `Map<String, Object>` as a parameter type is
  prohibited for public APIs.
- TypeScript interfaces MUST be defined in `types.ts` for all configuration,
  message, and response shapes. The `any` type is prohibited in public API
  signatures.
- JSON Schema definitions for MCP tool inputs MUST specify types, required
  fields, and descriptions for every property. Open-ended
  `additionalProperties: true` is prohibited unless the use case genuinely
  requires arbitrary keys.
- Error classes MUST be specific (e.g., `SalesforceAuthError`, `RemoteMcpError`)
  rather than generic. Callers MUST be able to distinguish error categories by
  type, not by string matching.

**Rationale**: Strong typing catches integration errors at compile time or schema
validation time rather than at runtime in production. For a library consumed by
machines, type precision is the primary contract.

## Technology Stack & Constraints

- **Apex (Salesforce)**: Source API version 65.0. All classes packaged as a
  second-generation package (2GP) under namespace `SalesforceMcpLib`.
- **TypeScript / Node.js**: Target ES2022+. Zero production dependencies. Build
  via `tsc`. Tests via Node.js built-in test runner with `tsx`.
- **Protocol Compliance**: JSON-RPC 2.0 (in-repo implementation). MCP
  specification version 2025-11-25. Both MUST be implemented fully -- partial
  compliance is treated as a defect.
- **Packaging**: Apex delivered as 2GP installable package. Node.js delivered as
  npm package (`salesforce-mcp-lib`).
- **Authentication**: OAuth 2.0 client credentials flow for Salesforce
  connectivity. No other auth mechanisms in scope for the bridge.
- **Scratch Org Development**: All Apex development and testing MUST use
  Salesforce scratch orgs. Production org direct deployment is prohibited during
  development.

## Development Workflow

- **Testing**: Tests MUST exist for all public interfaces. TypeScript tests use
  the Node.js built-in test runner. Apex tests use the native Salesforce test
  framework. Test coverage MUST be sufficient for 2GP package promotion.
- **Versioning**: The Apex 2GP package and npm package MUST follow semantic
  versioning independently. Breaking changes to public interfaces require a
  MAJOR version bump in the affected package.
- **Protocol Changes**: Any modification to MCP or JSON-RPC message handling MUST
  be validated against the relevant specification. Wire-contract audits MUST be
  performed before release.
- **Examples**: The `examples/` directory MUST contain runnable, tested examples
  that demonstrate library usage. Examples MUST be updated when public APIs
  change.
- **Scripts**: Automation scripts in `scripts/` MUST be idempotent and
  documented. Each script MUST include a usage comment at the top.

## Governance

This constitution is the authoritative source for project standards. All
development -- whether by human or AI agent -- MUST comply with these principles.

- **Compliance**: Every pull request and code review MUST verify adherence to
  these principles. Non-compliance MUST be flagged and resolved before merge.
- **Amendments**: Changes to this constitution require: (1) a written proposal
  describing the change and rationale, (2) review of downstream impact on
  templates and existing artifacts, (3) a version bump following the versioning
  rules below.
- **Version Policy**: MAJOR for principle removals or redefinitions that change
  enforcement expectations. MINOR for new principles, sections, or materially
  expanded guidance. PATCH for clarifications, wording fixes, and non-semantic
  refinements.
- **Conflict Resolution**: When a principle conflicts with a practical
  constraint, the constraint MUST be documented in a Complexity Tracking table
  (see plan template) with justification for the deviation.

**Version**: 1.0.0 | **Ratified**: 2026-03-28 | **Last Amended**: 2026-03-28
