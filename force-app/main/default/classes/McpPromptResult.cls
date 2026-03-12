/**
 * @description Typed MCP prompt resolution payload.
 */
public inherited sharing class McpPromptResult extends JsonRpcResultBase {
    public String description;
    public List<McpPromptMessage> messages = new List<McpPromptMessage>();

    public override void validate() {
        if (this.messages == null) {
            throw new McpInvalidParamsException('Prompt messages list is required.');
        }

        for (McpPromptMessage item : this.messages) {
            if (item == null) {
                throw new McpInvalidParamsException('Prompt message cannot be null.');
            }
            item.validate();
        }
    }
}
