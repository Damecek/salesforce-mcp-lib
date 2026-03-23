/**
 * @description Typed wire DTO returned from tools/list.
 */
public inherited sharing class McpListedTool {
    public String name;
    public String description;
    public String inputSchemaJson;
    public McpToolAnnotationsWire annotations;

    public McpListedTool() {
    }

    /**
     * @description Builds a listed tool DTO from a tool definition.
     * @param source Tool definition.
     */
    public McpListedTool(McpToolDefinition source) {
        if (source == null) {
            return;
        }
        this.name = source.name;
        this.description = source.description;
        this.inputSchemaJson = JSON.serialize(source.listedInputSchema());
        this.annotations = source.annotations == null ? null : new McpToolAnnotationsWire(source.annotations);
    }

    /**
     * @description Validates required wire fields.
     */
    public void validate() {
        if (String.isBlank(this.name)) {
            throw new McpInvalidParamsException('Tool definition name is required.');
        }
        if (String.isBlank(this.inputSchemaJson)) {
            throw new McpInvalidParamsException('Tool definition inputSchema is required.');
        }
    }

    /**
     * @description Builds a null-clean wire map for JSON serialization.
     * @return Wire map with only non-null, non-empty optional fields included.
     */
    public Map<String, Object> toWire() {
        this.validate();

        Map<String, Object> wire = new Map<String, Object>{
            'name' => this.name,
            'inputSchema' => JSON.deserializeUntyped(this.inputSchemaJson)
        };

        if (!String.isBlank(this.description)) {
            wire.put('description', this.description);
        }

        if (this.annotations != null && this.annotations.hasValues()) {
            wire.put('annotations', this.annotations.toWire());
        }

        return wire;
    }
}
