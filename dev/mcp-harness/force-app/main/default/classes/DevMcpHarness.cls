/**
 * Development harness REST endpoint for scratch org testing.
 */
@RestResource(urlMapping='/mcp/harness')
global with sharing class DevMcpHarness {
    @HttpPost
    global static void post() {
        new McpServer('dev-harness', '1.0.0')
            .tool(new DevMcpHarnessTool())
            .resource(new DevMcpHarnessResource())
            .prompt(new DevMcpHarnessPrompt())
            .handle(RestContext.request, RestContext.response);
    }
}
