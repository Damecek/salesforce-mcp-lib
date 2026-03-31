/**
 * Development harness greeting prompt.
 */
public class DevMcpHarnessPrompt extends McpPromptDefinition {
    public DevMcpHarnessPrompt() {
        this.name = 'dev_greet';
        this.description = 'Development harness greeting prompt';
        this.arguments = new List<McpPromptArgumentDefinition>{
            new McpPromptArgumentDefinition('name', 'Name to greet', true)
        };
    }
    public override McpPromptResult get(Map<String, String> arguments) {
        McpPromptResult result = new McpPromptResult();
        result.description = 'Greeting for ' + arguments.get('name');
        result.messages = new List<McpPromptMessage>{
            new McpPromptMessage('user', new McpTextContent('Hello, ' + arguments.get('name') + '! Welcome to the MCP harness.'))
        };
        return result;
    }
}
