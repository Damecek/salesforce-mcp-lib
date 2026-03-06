/**
 * @description Declarative resource template descriptor exposed by the MCP library.
 */
public inherited sharing class McpResourceTemplateDefinition {
    /** @description Stable template name used by call endpoint. */
    public String name;
    /** @description URI template string. */
    public String uriTemplate;
    /** @description Optional textual description. */
    public String description;

    /**
     * @description Creates a template descriptor.
     * @param templateName Stable template name.
     * @param templateUri URI template pattern.
     */
    public McpResourceTemplateDefinition(String templateName, String templateUri) {
        this.name = templateName;
        this.uriTemplate = templateUri;
    }

    /** @description Validates required descriptor fields. */
    public void validate() {
        if (String.isBlank(this.name)) {
            throw new McpInvalidParamsException('Resource template name is required.');
        }

        if (String.isBlank(this.uriTemplate)) {
            throw new McpInvalidParamsException('Resource template uriTemplate is required.');
        }
    }

    /**
     * @description Converts this descriptor into a serializable map.
     * @return Map representation used in MCP responses.
     */
    public Map<String, Object> toMap() {
        validate();

        return new Map<String, Object>{
            'name' => this.name,
            'uriTemplate' => this.uriTemplate,
            'description' => this.description
        };
    }
}
