/**
 * @description Declarative prompt descriptor exposed by the MCP library.
 */
public inherited sharing class McpPromptDefinition {
    /** @description Stable prompt name. */
    public String name;
    /** @description Optional prompt description. */
    public String description;
    /** @description Optional list of argument descriptors. */
    public List<Object> arguments;

    /**
     * @description Creates a prompt descriptor.
     * @param promptName Stable prompt name.
     * @param promptDescription Human-readable description.
     */
    public McpPromptDefinition(String promptName, String promptDescription) {
        this.name = promptName;
        this.description = promptDescription;
    }

    /** @description Validates required descriptor fields. */
    public void validate() {
        if (String.isBlank(this.name)) {
            throw new McpInvalidParamsException('Prompt name is required.');
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

        if (this.arguments != null) {
            payload.put('arguments', this.arguments);
        }

        return payload;
    }
}
