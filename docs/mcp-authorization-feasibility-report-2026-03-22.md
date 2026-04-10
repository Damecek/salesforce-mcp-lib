# MCP Authorization Feasibility Report

**Date**: 2026-03-22 (analysis) / 2026-03-30 (implementation)
**Context**: SalesforceMcpLib v1.1.0 — OAuth 2.0 client credentials flow

## Summary

The MCP server framework delegates authentication and authorization entirely to the Salesforce platform's existing security model. The TypeScript proxy handles OAuth 2.0 authentication; the Apex endpoint inherits the Run As user's permissions.

## Authentication Architecture

### Flow
1. Proxy authenticates via OAuth 2.0 client credentials to Salesforce
2. External Client App issues access token scoped to the Run As user
3. Proxy includes Bearer token in all API requests
4. Salesforce enforces profile/permission set permissions per request
5. Token expiration triggers transparent re-authentication

### Security Properties
- **No stored credentials in Salesforce**: Token management is proxy-side only
- **Principle of least privilege**: Run As user permissions limit API access
- **Session timeout**: Governed by org session settings (default ~2h)
- **IP restrictions**: Configurable via External Client App policies

## Authorization Model

| Layer | Enforcement | Mechanism |
|---|---|---|
| API Access | Salesforce Platform | External Client App OAuth scopes |
| Object/Field Access | Salesforce Platform | Profile + Permission Sets |
| Record Access | Salesforce Platform | OWD + Sharing Rules |
| Tool Authorization | Subscriber Code | Custom logic in validate/execute |

## Limitations

1. No per-tool authorization at the framework level — subscriber developers implement access checks in tool/resource/prompt code
2. All tools share the same Run As user's permissions within a single endpoint
3. Multiple permission levels require multiple @RestResource endpoints with different External Client Apps

## Recommendation

The current model is sufficient for v1. Framework-level authorization (e.g., custom permission checks per tool) can be added in a future version without breaking changes.
