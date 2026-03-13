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

    public Map<String, Object> toWire() {
        List<Object> wirePrompts = new List<Object>();
        for (McpListedPrompt definition : this.prompts) {
            wirePrompts.add(definition.toWire());
        }

        return new Map<String, Object>{
            'prompts' => wirePrompts
        };
    }
}
