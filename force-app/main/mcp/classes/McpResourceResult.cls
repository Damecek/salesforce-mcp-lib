/**
 * @description Typed MCP resource read or template resolution payload.
 */
public inherited sharing class McpResourceResult extends JsonRpcResultBase {
    public List<McpResourceContentItem> contents = new List<McpResourceContentItem>();

    public override void validate() {
        if (this.contents == null) {
            throw new McpInvalidParamsException('Resource contents list is required.');
        }
        for (McpResourceContentItem item : this.contents) {
            if (item == null) {
                throw new McpInvalidParamsException('Resource content item cannot be null.');
            }
            item.validate();
        }
    }
}
