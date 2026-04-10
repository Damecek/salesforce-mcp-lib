# Image Prompt: Post 9 — The Proxy Solves a Real Problem, But It Should Not Be Treated as Sacred

**Post**: 9
**Source variant**: founder
**Visual concept**: Before/After Split
**Generated**: 2026-04-10

## Core Message (for visual)

Removing the proxy does not remove complexity from a Salesforce MCP setup — it transfers ownership of auth, token handling, and transport compatibility to another layer such as the host or workflow tool.

## Gemini Prompt

Create a LinkedIn infographic (1200x627px, landscape).

**Visual concept**: A clean split-screen diagram comparing two valid ways to connect an AI agent to a Salesforce MCP endpoint. The left side shows a dedicated proxy layer handling token and transport concerns. The right side shows a direct connection where those same concerns move into the host/workflow layer instead. The visual should make it obvious that the complexity did not disappear; it changed owners.

**Layout**:
- Left side header: "With Proxy"
- Left side body: A simple horizontal flow of three rounded boxes connected by arrows: "MCP Host" -> "Proxy" -> "Salesforce MCP Endpoint"
- Under the left-side "Proxy" box, place three small pill-shaped labels: "OAuth Token", "Session Retry", "Transport Bridge"
- Right side header: "Direct Connection"
- Right side body: A similar horizontal flow of three rounded boxes connected by arrows: "MCP Host / Workflow" -> "Salesforce MCP Endpoint"
- Under the leftmost box on the right side, place the same three pill-shaped labels: "OAuth Token", "Session Retry", "Transport Compatibility"
- Center divider: A subtle vertical dividing line with a small caption in the middle reading "Same responsibilities, different owner"
- Bottom center: A narrow footer strip with the label "salesforce-mcp-lib" in a clean monospace style

**Style**: Clean, modern, professional infographic on a dark navy background (#0F172A) with slightly lighter panels in charcoal-blue (#162033). Use Salesforce blue (#0176D3) for arrows, borders, and emphasis. Use white text and muted blue-gray secondary text. Rounded rectangles, subtle glow, precise spacing, no visual clutter. Typography should feel like a polished architecture slide, not a marketing poster.

**Text labels** (exact text to include):
- "With Proxy"
- "Direct Connection"
- "MCP Host"
- "Proxy"
- "Salesforce MCP Endpoint"
- "MCP Host / Workflow"
- "OAuth Token"
- "Session Retry"
- "Transport Bridge"
- "Transport Compatibility"
- "Same responsibilities, different owner"
- "salesforce-mcp-lib"

**Do NOT include**: No photos of people, no generic AI brain imagery, no clipart robots, no Salesforce logo, no cloud logo, no code screenshots, no terminal screenshots, no busy dashboards, no unnecessary decorative icons.

## Alt Text (for LinkedIn)

Split-screen infographic comparing two Salesforce MCP connection patterns: on the left, an MCP host connects through a proxy to a Salesforce MCP endpoint, with the proxy handling OAuth token, session retry, and transport bridge duties; on the right, a direct connection moves those same responsibilities into the host or workflow layer. A center caption reads "Same responsibilities, different owner."

## Usage Notes

- **LinkedIn image specs**: 1200x627px recommended for feed posts
- **Fallback**: If generation fails, use the alt text as a text-only post header
- **Regeneration**: Adjust the prompt and re-run if the visual doesn't match the post's tone
