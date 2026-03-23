/**
 * @description Declarative resource descriptor exposed by the MCP library.
 */
public inherited sharing class McpResourceDefinition {
    /** @description Stable resource URI. */
    public String uri;
    /** @description Human-readable resource name. */
    public String name;
    /** @description Optional textual description. */
    public String description;
    /** @description Optional MIME type of resource payload. */
    public String mimeType;

    public McpResourceDefinition() {
    }

    /**
     * @description Creates a resource descriptor.
     * @param resourceUri Stable resource URI.
     * @param resourceName Human-readable name.
     */
    public McpResourceDefinition(String resourceUri, String resourceName) {
        this.uri = resourceUri;
        this.name = resourceName;
    }

    /**
     * @description Validates required descriptor fields.
     */
    public void validate() {
        if (String.isBlank(this.uri)) {
            throw new McpInvalidParamsException('Resource uri is required.');
        }
        if (String.isBlank(this.name)) {
            throw new McpInvalidParamsException('Resource name is required.');
        }
    }
}
