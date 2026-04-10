# Post 8 - Business: Do Not Treat Tool Visibility and Trust Boundaries as the Same Problem

**Topic**: 8 - Do Not Treat Tool Visibility and Trust Boundaries as the Same Problem
**Variant**: Business
**Word count**: 219
**Claims referenced**: [C-007, C-011, C-014]

---

When teams start exposing Salesforce capabilities to AI agents, one question appears almost immediately:
should every user hit the same MCP endpoint, or should different agent groups get different endpoints?

There are really two different problems hidden inside that question.

The first is tool visibility. Maybe support users should see case tools, sales users should see account tools, and admins should see both. In `salesforce-mcp-lib`, that can be handled inside one endpoint because the tool registry is explicit and rebuilt per request. You can register tools conditionally and let the endpoint advertise only what the current user should discover.

The second is boundary design. Maybe one agent is read-only, another can update production records, and a third is partner-facing with a narrower contract. That is not just visibility. That is a different risk profile. In that case, separate MCP endpoints are usually the cleaner answer because they create a harder operational boundary around authentication, rollout, and failure impact.

My rule of thumb is simple:

use custom-permission-gated registration when users are part of the same product surface and you want fine-grained tool exposure.

use separate endpoints when you need strong isolation between agent classes, client apps, or trust levels.

If you blur those two concerns together, the design gets messy fast. If you separate them, the architecture usually becomes obvious.
