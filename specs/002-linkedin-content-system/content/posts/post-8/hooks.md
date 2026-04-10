# Hooks: Post 8 - Dynamic Tool Registration or Separate Endpoints? Pick the Boundary Deliberately

**Topic**: 8 - Dynamic Tool Registration or Separate Endpoints? Pick the Boundary Deliberately

## 1. Pain-First

Teams keep turning one Salesforce agent integration question into an architecture knot:
should users get different tools from one MCP endpoint, or should every variation become a new endpoint?

## 2. Misconception-First

Dynamic tool registration and separate endpoints are not competing patterns.
They solve two different jobs: visibility inside a boundary, and isolation between boundaries.

## 3. Architecture-First

Because `salesforce-mcp-lib` registers tools programmatically on every request, you can gate `registerTool()` with `FeatureManagement.checkPermission()` and advertise only what the current user should see.

## 4. Business-First

If your real problem is trust separation, adding more `if` statements inside one endpoint is the wrong fix.
Different risk profiles usually deserve different MCP contracts, auth policies, and rollout paths.

## 5. Curiosity-First

What if the right answer is both?
One endpoint for the read-only assistant, another for the write-capable agent, and custom-permission-driven tool visibility inside each.
