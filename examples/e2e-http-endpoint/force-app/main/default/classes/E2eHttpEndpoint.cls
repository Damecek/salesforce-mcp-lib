/**
 * Full MCP endpoint demonstrating tools, resources, resource templates and prompts.
 */
@RestResource(urlMapping='/mcp/e2e')
global with sharing class E2eHttpEndpoint {
    @HttpPost
    global static void post() {
        new McpServer('e2e-example', '1.0.0')
            .title('End-to-end example')
            .instructions('Call query_accounts to find accounts, then read one through salesforce://account/{id}.')
            .tool(new ExampleQueryTool())
            .resource(new ExampleOrgResource())
            .resourceTemplate(new ExampleAccountTemplate())
            .prompt(new ExampleSummarizePrompt())
            .handle(RestContext.request, RestContext.response);
    }
}
