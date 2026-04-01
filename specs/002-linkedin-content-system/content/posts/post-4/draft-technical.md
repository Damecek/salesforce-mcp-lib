# Post 4 — Technical: Four Layers of Security You Didn't Have to Build

**Topic**: 4 — Four Layers of Security You Didn't Have to Build
**Variant**: Technical
**Word count**: 276
**Claims referenced**: [C-014, C-010, C-016, C-018]

---

Most AI integration frameworks hand you a tool executor and leave authorization as an exercise for the reader. You end up building a parallel permission system — one for your users, one for your agents — and praying they stay in sync.

Salesforce MCP Library takes a different approach: it builds nothing new for security.

When an AI agent calls a tool through the library, the request passes through four authorization layers that already exist in your org. First, the External Client App's OAuth scopes control which APIs the agent can reach at all. Second, the Profile and Permission Sets assigned to the integration user enforce object-level and field-level visibility — the agent literally cannot see fields your security model hides. Third, OWD and Sharing Rules govern which records the agent can access, identical to any other user context. Fourth, developers implement a `validate()` method on their tool class to add business-specific authorization logic before execution.

The developer surface stays minimal. You extend four abstract classes — `McpToolDefinition` with 3 methods, `McpResourceDefinition`, `McpResourceTemplateDefinition`, and `McpPromptDefinition` with 1 method each. The framework handles protocol compliance, capability advertisement, and error translation behind those abstractions.

Two details matter for production: the server performs automatic re-authentication with a single retry on `INVALID_SESSION_ID`, so expired tokens don't surface as errors to the AI agent. And raw Salesforce error messages never reach MCP clients — the framework sanitizes them before they cross the protocol boundary.

The result is that your AI agents operate under the exact same security policies as your human users. No shadow permission system. No new infrastructure to audit.

Review the four abstract classes in the repo and map them to your org's existing permission model.
