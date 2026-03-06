@RestResource(urlMapping='/mcp-example')
global inherited sharing class ExampleMcpEndpoint {
    @HttpPost
    global static void handlePost() {
        McpHttpTransport.handlePost(ExampleMcpServerFactory.build());
    }
}
