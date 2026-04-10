# Post 9 - Founder: The Proxy Solves a Real Problem, But It Should Not Be Treated as Sacred

**Topic**: 9 - The Proxy Solves a Real Problem, But It Should Not Be Treated as Sacred
**Variant**: Founder
**Word count**: 203
**Claims referenced**: [C-004, C-015, C-016]

---

I built the proxy because there was a practical gap to solve.

Many MCP hosts expect a local stdio process. Salesforce gives you an HTTP endpoint. Something has to sit in the middle, own the token, forward the JSON-RPC payloads, and deal with expired sessions. That is the job the TypeScript layer takes on in this repo.

What I do not want people to conclude from that is that the proxy is somehow the product.

It is not. The Apex endpoint is the actual MCP server. The proxy is a compatibility layer and an operational convenience layer.

So yes, there are cases where I would skip it. If the host can connect directly to a remote MCP server and I am comfortable handling OAuth outside the package, direct connection is a reasonable design. In n8n, for example, you can obtain a Salesforce token with one HTTP step and reuse that bearer token in the MCP connection for the session.

The important part is being honest about the trade.

If you remove the proxy, you are not removing complexity. You are taking ownership of it in another place.

That can be the right move. It just should be a deliberate one, not a reflex.
