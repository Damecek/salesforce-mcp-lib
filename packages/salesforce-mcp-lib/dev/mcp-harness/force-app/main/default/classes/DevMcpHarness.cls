@RestResource(urlMapping='/mcp/harness')
global class DevMcpHarness {
    @HttpPost
    global static void handlePost() {
        McpServer server = new McpServer();
        server.registerTool(new DevMcpHarnessTool());
        server.registerResource(new DevMcpHarnessResource());
        server.registerPrompt(new DevMcpHarnessPrompt());
        server.handleRequest(RestContext.request, RestContext.response);
    }
}
