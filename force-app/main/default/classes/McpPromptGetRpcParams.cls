/**
 * @description JSON-RPC params DTO for prompts/get.
 */
public inherited sharing class McpPromptGetRpcParams extends McpNamedArgumentsParams {
    protected override String methodNameForValidation() {
        return 'prompts/get';
    }
}
