# Image Prompt: Post 8 — Do Not Treat Tool Visibility and Trust Boundaries as the Same Problem

**Post**: 8
**Source variant**: business
**Visual concept**: Mapping/Translation
**Generated**: 2026-04-10

## Core Message (for visual)

In Salesforce MCP design, tool visibility and trust boundaries are two different problems, and they usually require two different solutions: dynamic tool registration for fine-grained exposure, and separate endpoints for hard isolation.

## Gemini Prompt

Create a LinkedIn infographic (1200x627px, landscape).

**Visual concept**: A clean two-column decision map showing that teams often confuse two separate architecture questions. The left column represents "Tool Visibility" and maps to conditional tool registration inside one endpoint. The right column represents "Trust Boundary" and maps to separate MCP endpoints. The design should feel like a precise architecture decision aid, not marketing art.

**Layout**:
- Top center: A short header strip with the title "Two Problems, Two Patterns"
- Left column card titled "Tool Visibility"
- Inside the left card: three small stacked labels representing user groups, such as "Support", "Sales", "Admin", all pointing into a single larger box labeled "One MCP Endpoint"
- Under that box: a smaller highlighted label reading "Conditional Tool Registration"
- Right column card titled "Trust Boundary"
- Inside the right card: three separate boxes labeled "Read-Only Agent", "Write Agent", and "Partner Agent"
- Each of those boxes points to its own endpoint box, creating a one-to-one separation pattern
- Under the right-side cluster: a smaller highlighted label reading "Separate MCP Endpoints"
- Bottom center: a narrow caption band reading "Visibility inside a boundary != isolation between boundaries"
- Bottom footer in small monospace: "salesforce-mcp-lib"

**Style**: Clean, modern, professional. Dark navy background (#0F172A) with slightly lighter panels (#172033). Salesforce blue (#0176D3) as the main accent color. Use white text, subtle blue connector arrows, and soft glow highlights around the two main decision patterns. Rounded rectangles, sharp spacing, strong alignment, and minimal ornamentation. Typography should resemble a polished enterprise architecture diagram.

**Text labels** (exact text to include):
- "Two Problems, Two Patterns"
- "Tool Visibility"
- "Trust Boundary"
- "Support"
- "Sales"
- "Admin"
- "One MCP Endpoint"
- "Conditional Tool Registration"
- "Read-Only Agent"
- "Write Agent"
- "Partner Agent"
- "Separate MCP Endpoints"
- "Visibility inside a boundary != isolation between boundaries"
- "salesforce-mcp-lib"

**Do NOT include**: No photos of people, no robot mascots, no generic AI brain imagery, no Salesforce logo, no cloud logo, no code screenshots, no terminal windows, no complex dashboards, no decorative 3D effects.

## Alt Text (for LinkedIn)

Infographic with two side-by-side architecture patterns for Salesforce MCP. The left side shows multiple user groups feeding into one MCP endpoint with conditional tool registration for visibility control. The right side shows separate agent types each using its own MCP endpoint to represent hard trust-boundary isolation. A caption at the bottom says "Visibility inside a boundary != isolation between boundaries."

## Usage Notes

- **LinkedIn image specs**: 1200x627px recommended for feed posts
- **Fallback**: If generation fails, use the alt text as a text-only post header
- **Regeneration**: Adjust the prompt and re-run if the visual doesn't match the post's tone
