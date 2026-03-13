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

    public McpListedResource(McpResourceDefinition source) {
        if (source == null) {
            return;
        }

        this.uri = source.uri;
        this.name = source.name;
        this.description = source.description;
        this.mimeType = source.mimeType;
    }

    public void validate() {
        if (String.isBlank(this.uri)) {
            throw new McpInvalidParamsException('Resource uri is required.');
        }

        if (String.isBlank(this.name)) {
            throw new McpInvalidParamsException('Resource name is required.');
        }
    }

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
