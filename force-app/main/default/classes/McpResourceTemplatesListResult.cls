/**
 * @description JSON-RPC result DTO for resources/templates/list.
 */
public inherited sharing class McpResourceTemplatesListResult extends JsonRpcResultBase {
    public List<McpListedResourceTemplate> resourceTemplates = new List<McpListedResourceTemplate>();

    public override void validate() {
        for (McpListedResourceTemplate definition : this.resourceTemplates) {
            if (definition == null) {
                throw new McpInvalidParamsException('Resource template definition cannot be null.');
            }
            definition.validate();
        }
    }
}
