/**
 * @description Declarative tool descriptor exposed by the MCP library.
 * @example
 * {@code
 * McpToolDefinition toolDef = new McpToolDefinition('math.sum', 'Sum two integers');
 * toolDef.inputSchema = new Map<String, Object>{ 'type' => 'object' };
 * }
 */
public inherited sharing class McpToolDefinition {
    /** @description Stable unique tool name. */
    public String name;
    /** @description Human-readable tool description. */
    public String description;
    /** @description Optional JSON-Schema-like input descriptor. */
    public Map<String, Object> inputSchema;
    /** @description Optional tool annotations. */
    public Map<String, Object> annotations;

    /**
     * @description Creates a tool descriptor.
     * @param toolName Unique tool name.
     * @param toolDescription Human-readable description.
     */
    public McpToolDefinition(String toolName, String toolDescription) {
        this.name = toolName;
        this.description = toolDescription;
    }

    /**
     * @description Validates required descriptor fields.
     */
    public void validate() {
        if (String.isBlank(this.name)) {
            throw new McpInvalidParamsException('Tool name is required.');
        }
    }

    /**
     * @description Converts this descriptor into a serializable map.
     * @return Map representation used in MCP responses.
     */
    public Map<String, Object> toMap() {
        validate();

        Map<String, Object> payload = new Map<String, Object>{
            'name' => this.name,
            'description' => this.description
        };

        if (this.inputSchema != null) {
            payload.put('inputSchema', this.inputSchema);
        }

        if (this.annotations != null) {
            payload.put('annotations', this.annotations);
        }

        return payload;
    }
}
