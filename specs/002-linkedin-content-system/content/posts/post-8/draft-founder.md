# Post 8 - Founder: Two Valid Patterns, Two Different Jobs

**Topic**: 8 - Two Valid Patterns, Two Different Jobs
**Variant**: Founder
**Word count**: 199
**Claims referenced**: [C-007, C-011, C-014]

---

I keep seeing people frame this as a binary choice:
either dynamically register tools per user, or create separate MCP endpoints.

I do not think that is the right framing.

Those two patterns solve different problems.

The reason dynamic registration works so well in this project is that the endpoint is just Apex code and registration happens on every request. `McpServer` is explicit by design. If the current user has a custom permission, register the tool. If not, do not. The agent then discovers only what is actually available in that request context.

That is great for progressive rollout, team-specific tools, and one shared MCP surface with different visibility rules.

But sometimes you need a harder line. Read-only agents and write-capable agents should not always be different views of the same endpoint. Sometimes they should be different endpoints, different client apps, and different operational contracts.

So my default position is:
separate endpoints for coarse trust boundaries.
custom permission checks for fine-grained exposure inside a boundary.

Once I started treating those as layered decisions instead of competing patterns, the design got much simpler.

Pick the boundary first. Then decide how dynamic you want the inside of that boundary to be.
