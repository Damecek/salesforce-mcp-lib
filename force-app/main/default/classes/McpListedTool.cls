/**
 * @description Typed wire DTO returned from tools/list.
 */
public inherited sharing class McpListedTool {
    public String name;
    public String description;
    public McpToolAnnotations annotations;

    public McpListedTool() {
    }

    public McpListedTool(McpToolDefinition source) {
        if (source == null) {
            return;
        }

        this.name = source.name;
        this.description = source.description;
        this.annotations = source.annotations;
    }

    public void validate() {
        if (String.isBlank(this.name)) {
            throw new McpInvalidParamsException('Tool definition name is required.');
        }
    }
}
