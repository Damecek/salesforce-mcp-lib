@RestResource(urlMapping='/mcp')
global inherited sharing class DevMcpHarnessEndpoint {
    @HttpPost
    global static void handlePost() {
        McpHttpTransport.handlePost(DevMcpHarnessServerFactory.build());
    }
}
