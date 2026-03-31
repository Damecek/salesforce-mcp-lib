public class MinimalTool extends McpToolDefinition {
    public MinimalTool() {
        this.name = 'echo';
        this.description = 'Echoes the provided message back to the caller';
    }

    public override Map<String, Object> inputSchema() {
        return new Map<String, Object>{
            'type' => 'object',
            'properties' => new Map<String, Object>{
                'message' => new Map<String, Object>{
                    'type' => 'string',
                    'description' => 'The message to echo'
                }
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
        String msg = (String) arguments.get('message');
        McpToolResult result = new McpToolResult();
        result.content = new List<McpTextContent>{ new McpTextContent(msg) };
        return result;
    }
}
