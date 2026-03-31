/**
 * Development harness echo tool for scratch org testing.
 */
public class DevMcpHarnessTool extends McpToolDefinition {
    public DevMcpHarnessTool() {
        this.name = 'dev_echo';
        this.description = 'Development harness echo tool for testing';
    }
    public override Map<String, Object> inputSchema() {
        return new Map<String, Object>{
            'type' => 'object',
            'properties' => new Map<String, Object>{
                'message' => new Map<String, Object>{ 'type' => 'string', 'description' => 'Message to echo' }
            },
            'required' => new List<String>{ 'message' }
        };
    }
    public override void validate(Map<String, Object> arguments) {
        if (!arguments.containsKey('message')) {
            throw new McpInvalidParamsException('message is required');
        }
    }
    public override McpToolResult execute(Map<String, Object> arguments) {
        McpToolResult result = new McpToolResult();
        result.content = new List<McpTextContent>{ new McpTextContent('Echo: ' + arguments.get('message')) };
        return result;
    }
}
