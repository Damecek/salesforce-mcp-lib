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

    /**
     * @description Builds a null-clean wire map for JSON serialization.
     * @return Wire map with resourceTemplates array.
     */
    public Map<String, Object> toWire() {
        List<Object> wireTemplates = new List<Object>();
        for (McpListedResourceTemplate definition : this.resourceTemplates) {
            wireTemplates.add(definition.toWire());
        }
        return new Map<String, Object>{ 'resourceTemplates' => wireTemplates };
    }
}
