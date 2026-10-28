/**
 * Minimal @RestResource endpoint exposing a single MCP tool.
 */
@RestResource(urlMapping='/mcp/minimal')
global with sharing class MinimalMcpEndpoint {
    @HttpPost
    global static void post() {
        new McpServer('minimal-example', '1.0.0')
            .tool(new MinimalTool())
            .handle(RestContext.request, RestContext.response);
    }
}
