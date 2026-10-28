/**
 * Minimal MCP tool that echoes the provided message.
 */
public with sharing class MinimalTool extends McpTool {
    public MinimalTool() {
        super('echo');
        title('Echo')
            .description('Echoes the provided message back to the caller')
            .input(McpSchema.obj()
                .requiredProperty('message', McpSchema.str().describe('The message to echo').minLength(1).maxLength(1000))
                .closed())
            .annotations(new McpToolAnnotations().readOnly(true).openWorld(false));
    }

    public override McpToolResult execute(McpRequest request) {
        return McpToolResult.text(request.requireString('message'));
    }
}
