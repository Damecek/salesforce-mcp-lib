/**
 * @description JSON-RPC params DTO for resources/templates/call.
 */
public inherited sharing class McpResourceTemplateCallRpcParams extends McpNamedArgumentsParams {
    protected override String methodNameForValidation() {
        return 'resources/templates/call';
    }
}
