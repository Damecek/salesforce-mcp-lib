/**
 * @description JSON-RPC result DTO for tools/list.
 */
public inherited sharing class McpToolsListResult extends JsonRpcResultBase {
    public List<McpListedTool> tools = new List<McpListedTool>();

    public override void validate() {
        for (McpListedTool definition : this.tools) {
            if (definition == null) {
                throw new McpInvalidParamsException('Tool definition cannot be null.');
            }
            definition.validate();
        }
    }

    /**
     * @description Builds a null-clean wire map for JSON serialization.
     * @return Wire map with tools array.
     */
    public Map<String, Object> toWire() {
        List<Object> wireTools = new List<Object>();
        for (McpListedTool definition : this.tools) {
            wireTools.add(definition.toWire());
        }
        return new Map<String, Object>{ 'tools' => wireTools };
    }
}
