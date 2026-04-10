# Post 9 - Business: The Proxy Is Not Extra Architecture. It Is a Deliberate Place to Put Complexity

**Topic**: 9 - The Proxy Is Not Extra Architecture. It Is a Deliberate Place to Put Complexity
**Variant**: Business
**Word count**: 221
**Claims referenced**: [C-004, C-015, C-016, C-018]

---

I have seen two reactions to the proxy in this project.

The first is: "Great, that makes local MCP clients easy to connect."
The second is: "Can we skip it?"

The honest answer is yes, sometimes. But only if you are also willing to own the jobs the proxy currently handles.

In `salesforce-mcp-lib`, the proxy is intentionally thin. It authenticates with OAuth client credentials, caches the token, retries once on expired sessions, and keeps raw Salesforce errors away from the agent. The Apex endpoint remains focused on tools, resources, prompts, and request handling inside Salesforce.

If your orchestration layer can speak directly to a remote MCP endpoint, going proxy-less can simplify deployment. That is especially attractive in hosted systems where running a local stdio process is awkward.

But "no proxy" does not mean "no operational work." You still need token acquisition, token refresh, bearer propagation, transport compatibility, and a clean story for what happens when Salesforce drops a session.

Take n8n as an example. One `HTTP Request` node can fetch a client credentials token, and another MCP-capable step can reuse that bearer token against the Apex endpoint. That can be the right design. It just means n8n is now where part of your MCP connection logic lives.

The proxy is not mandatory. It is a decision about where complexity should sit.
