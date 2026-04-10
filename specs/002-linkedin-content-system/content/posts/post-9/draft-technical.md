# Post 9 - Technical: The Proxy Is Optional. Transport and Token Ownership Are Not

**Topic**: 9 - The Proxy Is Optional. Transport and Token Ownership Are Not
**Variant**: Technical
**Word count**: 246
**Claims referenced**: [C-004, C-015, C-016, C-018]

---

It is worth being precise about what the proxy in `salesforce-mcp-lib` actually does.

It is not where MCP business logic lives. The Apex endpoint is the MCP server. The proxy is the stateful bridge that exists for hosts which want a local stdio process while Salesforce gives you an HTTP endpoint.

In the repo, the split is clean: the Apex side stays stateless per request, while the TypeScript layer owns token acquisition, cached auth state, transport bridging, and a single re-auth retry on `INVALID_SESSION_ID`. It also sanitizes remote errors before they cross back to the client.

That means the proxy is useful, but it is not mandatory in every architecture. If your MCP host can connect directly to a remote HTTP MCP server and you are willing to manage bearer tokens yourself, you can point it straight at the Apex REST endpoint.

The trade-off is that the complexity does not disappear. You are relocating it.

For example, in n8n the direct pattern can look like this:
1. `HTTP Request` node posts to `/services/oauth2/token` with `grant_type=client_credentials`, `client_id`, and `client_secret`.
2. Store `access_token` from the response.
3. Pass `Authorization: Bearer <token>` to the remote MCP connection targeting `/services/apexrest/mcp/...`.

That is perfectly workable if your chosen n8n MCP node supports the transport your Apex endpoint exposes. If not, the proxy remains the cleaner compatibility layer.

So the real question is not "can I remove the proxy?"

It is "which component should own auth refresh, transport translation, and failure handling?"
