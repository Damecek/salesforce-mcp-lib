@RestResource(urlMapping='/mcp/e2e')
global class E2eHttpEndpoint {
    @HttpPost
    global static void handlePost() {
        McpServer server = new McpServer();
        server.registerTool(new ExampleQueryTool());
        server.registerResource(new ExampleOrgResource());
        server.registerPrompt(new ExampleSummarizePrompt());
        server.handleRequest(RestContext.request, RestContext.response);
    }
}
