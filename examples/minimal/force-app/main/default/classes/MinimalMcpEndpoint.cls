/**
 * Minimal @RestResource endpoint exposing a single MCP tool.
 */
@RestResource(urlMapping='/mcp/minimal')
global inherited sharing class MinimalMcpEndpoint {
    @HttpPost
    global static void handlePost() {
        McpServer server = new McpServer();
        server.registerTool(new MinimalTool());
        server.handleRequest(RestContext.request, RestContext.response);
    }
}
