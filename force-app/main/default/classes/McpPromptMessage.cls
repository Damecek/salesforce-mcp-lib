/**
 * @description Typed MCP prompt message payload.
 */
public inherited sharing class McpPromptMessage {
    public String role;
    public List<McpTextContent> content = new List<McpTextContent>();

    public void validate() {
        if (String.isBlank(this.role)) {
            throw new McpInvalidParamsException('Prompt message role is required.');
        }

        if (this.content == null) {
            throw new McpInvalidParamsException('Prompt message content list is required.');
        }

        for (McpTextContent item : this.content) {
            if (item == null) {
                throw new McpInvalidParamsException('Prompt message content item cannot be null.');
            }
            item.validate();
        }
    }
}
