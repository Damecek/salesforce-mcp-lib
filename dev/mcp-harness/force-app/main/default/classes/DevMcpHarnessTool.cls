/**
 * Development harness echo tool for scratch org testing.
 */
public with sharing class DevMcpHarnessTool extends McpTool {
    public DevMcpHarnessTool() {
        super('dev_echo');
        description('Development harness echo tool for testing')
            .input(McpSchema.obj().requiredProperty('message', McpSchema.str().describe('Message to echo')));
    }

    public override McpToolResult execute(McpRequest request) {
        return McpToolResult.text('Echo: ' + request.requireString('message'));
    }
}
