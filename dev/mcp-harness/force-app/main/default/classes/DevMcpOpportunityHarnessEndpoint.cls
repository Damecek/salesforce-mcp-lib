@RestResource(urlMapping='/opportunity/mcp')
global inherited sharing class DevMcpOpportunityHarnessEndpoint {
    @HttpPost
    global static void handlePost() {
        McpHttpTransport.handlePost(DevMcpHarnessServerFactory.build());
    }
}
