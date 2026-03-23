# MCP Authorization Feasibility Report For Salesforce Apex

## Summary

This report compares MCP authorization requirements from spec `2025-11-25` with the practical implementation surface available in Salesforce Apex.

Decision summary:

- A fully custom OAuth authorization server implemented in Apex is not the right target.
- A direct Apex MCP endpoint backed by Salesforce OAuth is feasible in a constrained design, but it still requires non-trivial transport and discovery work and should be treated as a prototype-first option.
- A local TypeScript proxy run through `npx` is the lower-risk path when we need predictable MCP OAuth interoperability across clients and full control over the authorization edge.

Recommended decision:

- If the goal is the fastest path to broad MCP client compatibility, build the local TypeScript proxy and let it be the actual MCP HTTP server.
- If the goal is to minimize moving parts and accept tighter coupling to Salesforce auth behavior, prototype direct Apex with Salesforce Connected App / External Client App as the authorization server.

## Inputs And Scope

Sources used:

- MCP spec `2025-11-25` from Context7 library `websites/modelcontextprotocol_io_specification_2025-11-25`
- MCP Inspector docs from Context7 library `modelcontextprotocol/inspector`
- Salesforce docs from Context7 library `damecek/salesforce-documentation-context`
- Current transport implementation in [`McpHttpTransport.cls`](/Users/adam/IdeaProjects/salesforce-mcp-lib/force-app/main/mcp/classes/McpHttpTransport.cls)
- Existing docs style in [`docs/mcp-wire-contract-audit-2025-11-25.md`](/Users/adam/IdeaProjects/salesforce-mcp-lib/docs/mcp-wire-contract-audit-2025-11-25.md)

Scope:

- Inbound auth for a remote MCP HTTP endpoint
- Whether Apex can satisfy MCP authorization expectations directly
- Whether a local TypeScript proxy is the safer architecture

Out of scope:

- Full implementation design for the chosen option
- Salesforce org-specific security review
- Packaging or release changes

## MCP Authorization Baseline

The MCP authorization model is straightforward in roles but strict in wire expectations:

- The MCP server is the OAuth 2.1 resource server.
- The authorization server can be hosted by the MCP server or be a separate system.
- MCP servers must expose Protected Resource Metadata per RFC 9728.
- Protected Resource Metadata must include at least one `authorization_servers` entry.
- MCP servers must implement at least one discovery mechanism:
  - `WWW-Authenticate` on `401 Unauthorized`, or
  - a well-known protected-resource document at a path relative to the MCP endpoint or at root.
- MCP clients must support both discovery mechanisms.
- Access tokens must be sent in the `Authorization: Bearer` header on every request.
- MCP servers must validate access tokens and must accept only tokens intended for that server.
- Authorization servers must implement OAuth 2.1 security expectations.
- Authorization servers and clients should support Client ID Metadata Documents.
- Dynamic Client Registration is optional, not required.

Important architectural consequence:

- MCP does not require the authorization server to be implemented inside the same runtime as the MCP server.
- That means a Salesforce-hosted MCP endpoint may point clients at Salesforce auth, or a separate proxy may terminate OAuth and talk to Salesforce behind the scenes.

## What Salesforce Gives Us

From the Salesforce side, the platform already provides substantial OAuth machinery:

- Connected Apps and External Client Apps provide standard OAuth endpoints for Salesforce APIs.
- Documented capabilities include authorization-code style settings, refresh token behavior, client credentials, custom scopes, token introspection, and PKCE-related configuration on External Client App policies.
- Salesforce exposes OpenID Connect related features, including an OpenID Connect discovery endpoint and discovery-visible custom scopes.
- Apex can build REST endpoints with `@RestResource`.
- Apex REST mappings are relative to `/services/apexrest/`.
- Apex can set custom response headers and status codes.
- Apex supports outbound HTTP callouts, including Named Credentials for outbound auth.
- Apex has auth extension points such as `Auth.AuthProviderPluginClass` and `Auth.Oauth2TokenExchangeHandler`, but those are integration hooks inside Salesforce auth flows, not a generic way to turn Apex into a first-class custom OAuth authorization server.

Important negative constraint:

- Named Credentials and External Credentials are for outbound callouts from Salesforce. They do not solve inbound OAuth for a custom Apex REST MCP endpoint.

## Current Project Starting Point

The current MCP transport is not auth-aware.

[`McpHttpTransport.cls`](/Users/adam/IdeaProjects/salesforce-mcp-lib/force-app/main/mcp/classes/McpHttpTransport.cls) currently:

- handles only POST
- always emits JSON-RPC success transport responses with `200` or `204`
- does not emit `401`
- does not emit `WWW-Authenticate`
- does not expose protected-resource metadata
- does not perform any token validation logic in the library layer

This means direct MCP authorization support is not a small incremental patch on top of the existing transport.

## Feasibility: Direct Apex With Salesforce OAuth

Direct Apex is feasible only if we use Salesforce as the authorization server, not if we try to recreate a full standards-grade OAuth server in Apex.

What is feasible:

- Expose the MCP endpoint as Apex REST under `/services/apexrest/...`
- Expose a protected-resource metadata document from Apex REST under a relative well-known path such as `/services/apexrest/.well-known/oauth-protected-resource`
- Point `authorization_servers` to Salesforce auth infrastructure
- Require Salesforce-issued bearer tokens for the Apex MCP endpoint
- Add MCP-specific error/status/header handling in transport code where the request reaches Apex

Why this is feasible:

- MCP allows a separate authorization server
- Salesforce already has the OAuth endpoints and discovery surface needed to act as that authorization server
- Apex REST can expose the extra metadata endpoint and can set custom headers/status when Apex handles the request

What is still risky or unclear:

- Salesforce commonly authenticates requests before Apex executes, so some unauthenticated requests may be intercepted by the platform rather than reaching custom transport logic. That weakens our control over `401` challenge behavior.
- The MCP spec only requires one protected-resource discovery mechanism, so we can rely on the well-known metadata document if necessary, but some client tooling is easier to work with when the `401` challenge is also under our control.
- We still need to verify that the relevant Salesforce issuer metadata and token semantics line up cleanly with the MCP clients we care about.
- The current transport only handles POST; compliant auth support likely needs a small auth/discovery transport surface around the existing JSON-RPC POST handler.
- Scope mapping between MCP capabilities and Salesforce OAuth scopes would need deliberate design. Salesforce scopes are platform-oriented, not MCP-oriented by default.

Net assessment:

- Direct Apex with Salesforce OAuth is plausible.
- Direct Apex with a custom Apex-built OAuth server is not plausible enough to justify the effort.

## Feasibility: Full OAuth Authorization Server In Apex

This option should be rejected.

Reasons:

- Salesforce already owns the standard OAuth surface under `/services/oauth2/...`.
- Apex does not provide a clean platform model for implementing a separate standards-grade authorization server with equivalent maturity.
- A full implementation would require secure handling of:
  - authorization endpoint UX
  - user login and consent
  - client registration and storage
  - token issuance
  - refresh token rotation
  - revocation and introspection behavior
  - authorization server metadata or OIDC discovery metadata
  - PKCE and public-client protections
- Doing all of that in custom Apex would be high-risk and would duplicate native Salesforce auth capabilities poorly.
- The documented Apex auth extension points are for plugging into Salesforce auth flows, not for replacing Salesforce with a custom OAuth product.

Conclusion for this branch:

- Do not implement a custom OAuth authorization server in Apex.

## Feasibility: Local TypeScript Proxy

This option is operationally the safest.

Recommended shape:

- The local TypeScript process is the actual MCP HTTP server exposed to MCP clients.
- The proxy performs standard OAuth with the client-facing auth flow.
- The proxy stores or manages the resulting credentials locally.
- The proxy then communicates with Salesforce using standard Salesforce OAuth and forwards only backend-safe requests to the Apex endpoint.

Why this architecture is strong:

- The MCP auth edge lives in an environment where OAuth 2.1 libraries, discovery handling, PKCE, callback handling, and token lifecycle management are straightforward.
- We get complete control over `401`, `WWW-Authenticate`, protected-resource metadata, scopes, and auth-server metadata alignment.
- The proxy can normalize Salesforce-specific details away from the MCP client.
- The proxy can adapt to Inspector and other strict MCP tooling without fighting platform-auth interception inside Salesforce.
- The Apex backend can stay focused on business execution and protocol payloads instead of browser auth flows.

Tradeoffs:

- More moving parts
- Local runtime requirement through `npx`
- Secure local credential handling becomes part of the solution
- Need a thin backend contract between proxy and Apex

## Decision Matrix

| Option | Spec fit | Platform risk | Implementation complexity | Client interoperability | Recommendation |
| --- | --- | --- | --- | --- | --- |
| Custom OAuth server in Apex | Low | Very high | Very high | Low | Reject |
| Direct Apex endpoint with Salesforce OAuth as auth server | Medium | Medium | Medium | Medium | Prototype if we want minimal architecture |
| Local TypeScript proxy as MCP edge, Salesforce behind it | High | Low | Medium | High | Preferred |

## Recommendation

Preferred recommendation:

1. Build a local TypeScript proxy and make it the MCP-facing HTTP server.
2. Use standard OAuth in the proxy.
3. Let the proxy call the Salesforce Apex endpoint with Salesforce-native credentials.

Why this is the recommended default:

- It matches the MCP auth model cleanly.
- It avoids trying to bend Apex into an OAuth server role it is not designed for.
- It gives us deterministic behavior for discovery, challenges, PKCE, callbacks, token storage, and client interoperability.
- It isolates Salesforce-specific auth constraints behind one adapter layer.

Acceptable fallback recommendation:

1. Prototype direct Apex only if the architecture strongly prefers no local proxy.
2. Use Salesforce Connected App / External Client App as the authorization server.
3. Add a protected-resource metadata endpoint in Apex REST.
4. Validate real MCP clients against that design before committing to it.

Gate for choosing direct Apex:

- We should only choose it after a live proof that the target MCP clients can complete discovery and authorization cleanly against Salesforce auth metadata and then call the Apex endpoint successfully.

## Concrete Next Steps

If we choose the proxy path:

1. Define the proxy as the only MCP-public endpoint.
2. Implement protected-resource metadata, `401` challenge behavior, and OAuth flow in TypeScript.
3. Keep the Apex endpoint behind the proxy and authenticate proxy-to-Salesforce with standard Salesforce OAuth.
4. Treat Apex as backend transport and execution only.

If we choose the direct Apex prototype path:

1. Add a dedicated Apex REST GET endpoint for protected-resource metadata.
2. Extend transport to support MCP auth-related status/header handling instead of POST-only `200`/`204`.
3. Configure Connected App / External Client App and map usable scopes.
4. Validate with MCP Inspector and at least one real MCP client.
5. Stop the effort if discovery or auth challenge behavior is blocked by Salesforce platform interception.

## Final Decision Statement

The decision basis is clear:

- OAuth per MCP spec should not be custom-built in Apex.
- Direct Apex is only viable when backed by Salesforce's native OAuth infrastructure and after client compatibility is proven.
- The safer and more generally correct architecture is a local TypeScript proxy that performs standard OAuth and brokers calls to Salesforce.
