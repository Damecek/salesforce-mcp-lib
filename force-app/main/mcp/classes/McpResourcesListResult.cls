/**
 * @description JSON-RPC result DTO for resources/list.
 */
public inherited sharing class McpResourcesListResult extends JsonRpcResultBase {
    public List<McpListedResource> resources = new List<McpListedResource>();

    public override void validate() {
        for (McpListedResource definition : this.resources) {
            if (definition == null) {
                throw new McpInvalidParamsException('Resource definition cannot be null.');
            }
            definition.validate();
        }
    }

    /**
     * @description Builds a null-clean wire map for JSON serialization.
     * @return Wire map with resources array.
     */
    public Map<String, Object> toWire() {
        List<Object> wireResources = new List<Object>();
        for (McpListedResource definition : this.resources) {
            wireResources.add(definition.toWire());
        }
        return new Map<String, Object>{ 'resources' => wireResources };
    }
}
