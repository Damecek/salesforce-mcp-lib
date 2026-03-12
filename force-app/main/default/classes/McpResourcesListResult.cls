/**
 * @description JSON-RPC result DTO for resources/list.
 */
public inherited sharing class McpResourcesListResult extends JsonRpcResultBase {
    public List<McpResourceDefinition> resources = new List<McpResourceDefinition>();

    public override void validate() {
        for (McpResourceDefinition definition : this.resources) {
            if (definition == null) {
                throw new McpInvalidParamsException('Resource definition cannot be null.');
            }
            definition.validate();
        }
    }
}
