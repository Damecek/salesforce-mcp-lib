/**
 * @description Typed wire DTO returned from resources/templates/list.
 */
public inherited sharing class McpListedResourceTemplate {
    public String name;
    public String uriTemplate;
    public String description;

    public McpListedResourceTemplate() {
    }

    public McpListedResourceTemplate(McpResourceTemplateDefinition source) {
        if (source == null) {
            return;
        }

        this.name = source.name;
        this.uriTemplate = source.uriTemplate;
        this.description = source.description;
    }

    public void validate() {
        if (String.isBlank(this.name)) {
            throw new McpInvalidParamsException('Resource template name is required.');
        }

        if (String.isBlank(this.uriTemplate)) {
            throw new McpInvalidParamsException('Resource template uriTemplate is required.');
        }
    }

    public Map<String, Object> toWire() {
        this.validate();

        Map<String, Object> wire = new Map<String, Object>{
            'name' => this.name,
            'uriTemplate' => this.uriTemplate
        };

        if (!String.isBlank(this.description)) {
            wire.put('description', this.description);
        }

        return wire;
    }
}
