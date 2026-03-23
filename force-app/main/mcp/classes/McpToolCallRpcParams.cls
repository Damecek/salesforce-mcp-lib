/**
 * @description JSON-RPC params DTO for tools/call.
 */
public inherited sharing class McpToolCallRpcParams extends McpNamedArgumentsParams {
    protected override String methodNameForValidation() {
        return 'tools/call';
    }
}
