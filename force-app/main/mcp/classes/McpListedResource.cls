/**
 * @description Typed wire DTO returned from resources/list.
 */
public inherited sharing class McpListedResource {
    public String uri;
    public String name;
    public String description;
    public String mimeType;

    public McpListedResource() {
    }

    /**
     * @description Builds a listed resource DTO from a resource definition.
     * @param source Resource definition.
     */
    public McpListedResource(McpResourceDefinition source) {
        if (source == null) {
            return;
        }
        this.uri = source.uri;
        this.name = source.name;
        this.description = source.description;
        this.mimeType = source.mimeType;
    }

    /**
     * @description Validates required wire fields.
     */
    public void validate() {
        if (String.isBlank(this.uri)) {
            throw new McpInvalidParamsException('Resource uri is required.');
        }
        if (String.isBlank(this.name)) {
            throw new McpInvalidParamsException('Resource name is required.');
        }
    }

    /**
     * @description Builds a null-clean wire map for JSON serialization.
     * @return Wire map with only non-null optional fields included.
     */
    public Map<String, Object> toWire() {
        this.validate();

        Map<String, Object> wire = new Map<String, Object>{
            'uri' => this.uri,
            'name' => this.name
        };

        if (!String.isBlank(this.description)) {
            wire.put('description', this.description);
        }

        if (!String.isBlank(this.mimeType)) {
            wire.put('mimeType', this.mimeType);
        }

        return wire;
    }
}
