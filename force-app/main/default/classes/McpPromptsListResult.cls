/**
 * @description JSON-RPC result DTO for prompts/list.
 */
public inherited sharing class McpPromptsListResult extends JsonRpcResultBase {
    public List<McpListedPrompt> prompts = new List<McpListedPrompt>();

    public override void validate() {
        for (McpListedPrompt definition : this.prompts) {
            if (definition == null) {
                throw new McpInvalidParamsException('Prompt definition cannot be null.');
            }
            definition.validate();
        }
    }
}
