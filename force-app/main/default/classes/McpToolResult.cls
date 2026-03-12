/**
 * @description Typed MCP tool call result payload.
 */
public inherited sharing class McpToolResult extends JsonRpcResultBase {
    public List<McpTextContent> content = new List<McpTextContent>();
    public Boolean isError = false;

    public override void validate() {
        if (this.isError == null) {
            throw new McpInvalidParamsException('Tool result isError flag is required.');
        }

        if (this.content == null) {
            throw new McpInvalidParamsException('Tool result content list is required.');
        }

        for (McpTextContent item : this.content) {
            if (item == null) {
                throw new McpInvalidParamsException('Tool result content item cannot be null.');
            }
            item.validate();
        }
    }
}
