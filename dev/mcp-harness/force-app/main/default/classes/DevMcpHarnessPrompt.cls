/**
 * Development harness greeting prompt.
 */
public with sharing class DevMcpHarnessPrompt extends McpPrompt {
    public DevMcpHarnessPrompt() {
        super('dev_greet');
        description('Development harness greeting prompt').argument('name', 'Name to greet', true);
    }

    public override McpPromptResult get(McpRequest request) {
        String name = request.promptArguments().get('name');
        return new McpPromptResult()
            .description('Greeting for ' + name)
            .user(McpContent.text('Hello, ' + name + '! Welcome to the MCP harness.'));
    }
}
